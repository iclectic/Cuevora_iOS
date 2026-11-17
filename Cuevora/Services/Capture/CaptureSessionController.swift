import AVFoundation
import Photos
import UIKit

struct SavedTake: Equatable {
    var fileName: String
    var duration: Double
    var partial: Bool
    var recoverable: Bool
}

final class CaptureSessionController: NSObject, ObservableObject {
    @Published var phase: RecordingPhase = .idle
    @Published var message: String?
    @Published var usingFrontCamera = true
    @Published var elapsed: TimeInterval = 0
    @Published var savedTake: SavedTake?
    @Published var previewURL: URL?
    @Published var discardedFileName: String?

    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "app.cuevora.capture")
    private var videoInput: AVCaptureDeviceInput?
    private var startedAt: Date?
    private var timer: Timer?
    private var countdownTask: Task<Void, Never>?
    private var previousIdleDisabled = false
    private var holdingAwake = false
    private var configured = false
    private var quality = "high"
    private var partialFinalize = false
    private var activeFileName: String?
    private var observing = false

    func prepare(quality: String) {
        self.quality = quality
        observeInterruptions()
        Task { await recoverOrphans() }
    }

    func requestStart(countdown: Int, quality: String) {
        self.quality = quality
        Task { @MainActor in
            let permissions = await self.permissions(request: true)
            let transition = RecordingReducer.reduce(
                phase: self.phase,
                action: .requestStart(countdown: countdown, permissions: permissions, freeBytes: self.freeBytes(), thermalSerious: self.thermalSerious)
            )
            self.apply(transition)
            if case let .countdown(seconds) = self.phase {
                self.runCountdown(seconds)
            } else if self.phase == .recording {
                self.beginFile()
            }
        }
    }

    func stop() { applyAction(.stop) }
    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        applyAction(.cancelCountdown)
    }
    func discard() { applyAction(.discardPreview) }
    func noteShareFailed() { applyAction(.shareFailed) }
    func switchCamera() { applyAction(.switchCamera) }
    func backgrounded() { applyAction(.backgrounded) }

    func shutdown() {
        countdownTask?.cancel()
        timer?.invalidate()
        releaseAwake()
        queue.async {
            if self.output.isRecording { self.output.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func saveCurrentToPhotos() {
        guard let previewURL else {
            message = "There is no recording to save."
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.message = "Photos access is off, so nothing was added. The recording is still in Cuevora."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: previewURL)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    self.message = success ? "Saved to Photos. The copy in Cuevora was kept." : "Photos could not save this video. The recording is still in Cuevora."
                }
            }
        }
    }

    private func applyAction(_ action: RecordingAction) {
        let transition = RecordingReducer.reduce(phase: phase, action: action)
        apply(transition)
        if case .switchCamera = action, transition.allowCameraSwitch {
            usingFrontCamera.toggle()
            configure(startRunning: true)
        }
    }

    private func apply(_ transition: RecordingTransition) {
        let wasRecording = phase == .recording
        if transition.finalizePartial { partialFinalize = true }
        phase = transition.phase
        if let message = transition.message { self.message = message }
        if wasRecording, case .stopping = transition.phase {
            stopFile()
        }
        if transition.deleteFile {
            let name = savedTake?.fileName ?? activeFileName
            if let name {
                RecordingFiles.removeFile(named: name)
                discardedFileName = name
            }
            savedTake = nil
            previewURL = nil
            activeFileName = nil
        }
    }

    private func runCountdown(_ seconds: Int) {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for remaining in stride(from: seconds, through: 1, by: -1) {
                self.phase = .countdown(remaining)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            let transition = RecordingReducer.reduce(phase: self.phase, action: .countdownFinished)
            self.phase = transition.phase
            if self.phase == .recording { self.beginFile() }
        }
    }

    private func beginFile() {
        holdAwake()
        partialFinalize = false
        configure(startRunning: true)
        let fileName = UUID().uuidString + ".mp4"
        activeFileName = fileName
        startedAt = Date()
        elapsed = 0
        do {
            let url = try RecordingFiles.folder().appendingPathComponent(fileName)
            FileManager.default.createFile(atPath: url.appendingPathExtension("writing").path, contents: Data())
            queue.async {
                if !self.session.isRunning { self.session.startRunning() }
                self.applyOrientation()
                self.output.startRecording(to: url, recordingDelegate: self)
            }
            startTimer()
        } catch {
            phase = .failed("The recording could not be started.")
            message = "Recovery failed"
        }
    }

    private func stopFile() {
        timer?.invalidate()
        queue.async {
            if self.output.isRecording {
                self.output.stopRecording()
            } else {
                DispatchQueue.main.async {
                    self.apply(RecordingReducer.reduce(phase: self.phase, action: .fileFailed("Recording had not started.")))
                }
            }
        }
    }

    private func configure(startRunning: Bool) {
        let front = usingFrontCamera
        let preset: AVCaptureSession.Preset = quality == "high" ? .hd1920x1080 : .hd1280x720
        queue.async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                DispatchQueue.main.async { self.message = "Audio could not be prepared for recording." }
            }
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(preset) { self.session.sessionPreset = preset }
            else if self.session.canSetSessionPreset(.high) { self.session.sessionPreset = .high }
            if let videoInput = self.videoInput { self.session.removeInput(videoInput) }
            let position: AVCaptureDevice.Position = front ? .front : .back
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) ?? AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoInput = input
            } else {
                DispatchQueue.main.async {
                    self.phase = .failed("This device does not have a camera Cuevora can use.")
                }
            }
            if !self.configured {
                if let audio = AVCaptureDevice.default(for: .audio), let input = try? AVCaptureDeviceInput(device: audio), self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
                self.configured = true
            }
            self.session.commitConfiguration()
            if startRunning && !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func applyOrientation() {
        guard let connection = output.connection(with: .video), connection.isVideoOrientationSupported else { return }
        let orientation = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.interfaceOrientation
        switch orientation {
        case .landscapeLeft: connection.videoOrientation = .landscapeLeft
        case .landscapeRight: connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
        default: connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    private func permissions(request: Bool) async -> CapturePermissions {
        async let camera = access(for: .video, request: request)
        async let microphone = access(for: .audio, request: request)
        return await CapturePermissions(camera: camera, microphone: microphone)
    }

    private func access(for media: AVMediaType, request: Bool) async -> CaptureAccess {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined:
            guard request else { return .unknown }
            let granted = await AVCaptureDevice.requestAccess(for: media)
            return granted ? .granted : .denied
        @unknown default: return .unavailable
        }
    }

    private func freeBytes() -> Int64 {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let capacity = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
        return capacity ?? 0
    }

    private var thermalSerious: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            self.elapsed = Date().timeIntervalSince(startedAt)
            if ProcessInfo.processInfo.thermalState == .critical {
                self.message = "The device is very warm. Cuevora is saving the take."
                self.applyAction(.interrupted("Thermal pressure"))
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func holdAwake() {
        guard !holdingAwake else { return }
        previousIdleDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        holdingAwake = true
    }

    private func releaseAwake() {
        guard holdingAwake else { return }
        UIApplication.shared.isIdleTimerDisabled = previousIdleDisabled
        holdingAwake = false
    }

    private func observeInterruptions() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterrupted(_:)), name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalChanged), name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private func sessionInterrupted(_ note: Notification) {
        let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
        let reason = raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
        let text: String
        switch reason {
        case .audioDeviceInUseByAnotherClient: text = "The microphone is being used by another app."
        case .videoDeviceInUseByAnotherClient: text = "The camera is being used by another app."
        case .videoDeviceNotAvailableInBackground: text = "The camera stopped because Cuevora was in the background."
        case .videoDeviceNotAvailableWithMultipleForegroundApps: text = "The camera stopped during multitasking."
        default: text = "Recording was interrupted."
        }
        DispatchQueue.main.async { self.applyAction(.interrupted(text)) }
    }

    @objc private func thermalChanged() {
        DispatchQueue.main.async {
            if ProcessInfo.processInfo.thermalState == .critical {
                self.applyAction(.interrupted("The device is too warm to keep recording."))
            }
        }
    }

    @objc private func routeChanged() {
        DispatchQueue.main.async {
            if self.phase == .recording {
                self.message = "The audio route changed. Recording continues if the microphone is still available."
            }
        }
    }

    private func recoverOrphans() async {
        guard let folder = try? RecordingFiles.folder() else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for marker in files where marker.pathExtension == "writing" {
            let movie = marker.deletingPathExtension()
            let asset = AVURLAsset(url: movie)
            let playable = (try? await asset.load(.isPlayable)) ?? false
            let duration = (try? await asset.load(.duration)).map { CMTimeGetSeconds($0) } ?? 0
            let take = SavedTake(fileName: movie.lastPathComponent, duration: duration.isFinite ? duration : 0, partial: true, recoverable: playable && duration > 0)
            await MainActor.run {
                self.savedTake = take
                self.previewURL = movie
                self.phase = playable && duration > 0 ? .preview(partial: true) : .failed("A previous recording could not be recovered. The file is still available to share or delete.")
                self.message = take.recoverable ? "A partial take was restored." : "Recovery failed"
            }
            try? FileManager.default.removeItem(at: marker)
        }
    }
}

extension CaptureSessionController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let finished = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        let failure = error?.localizedDescription ?? "The recording file could not be finished."
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.releaseAwake()
            try? FileManager.default.removeItem(at: outputFileURL.appendingPathExtension("writing"))
            guard finished else {
                self.applyAction(.fileFailed(failure))
                return
            }
            let duration = self.startedAt.map { Date().timeIntervalSince($0) } ?? self.elapsed
            self.savedTake = SavedTake(fileName: outputFileURL.lastPathComponent, duration: duration, partial: self.partialFinalize, recoverable: true)
            self.previewURL = outputFileURL
            self.applyAction(.fileReady(partial: self.partialFinalize))
        }
    }
}
