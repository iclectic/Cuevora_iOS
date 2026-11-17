import AVFoundation
import Foundation
import Speech

@MainActor
final class OnDeviceSpeech: NSObject, ObservableObject {
    @Published private(set) var listening = false
    @Published private(set) var lastTranscript = ""
    @Published private(set) var events: [TranscriptEvent] = []
    @Published private(set) var message: String?
    @Published private(set) var commandToken = 0
    @Published private(set) var latestCommand: VoiceCommand = .unknown

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var recordingInProgress = false
    private var tapInstalled = false

    var localeIdentifier: String { Locale.current.identifier }

    func setRecordingInProgress(_ recording: Bool) {
        recordingInProgress = recording
        if recording { stop(reason: SpeechPrivacy.recordingContentionNote) }
    }

    func start() {
        let gate = SpeechGate(
            onDeviceSupported: SFSpeechRecognizer(locale: .current)?.supportsOnDeviceRecognition == true,
            permissionGranted: SFSpeechRecognizer.authorizationStatus() != .denied && SFSpeechRecognizer.authorizationStatus() != .restricted,
            recordingInProgress: recordingInProgress,
            localeIdentifier: localeIdentifier
        )
        guard gate.onDeviceSupported else {
            message = SpeechGate(onDeviceSupported: false, permissionGranted: true, recordingInProgress: false, localeIdentifier: localeIdentifier).unavailableReason
            return
        }
        guard !recordingInProgress else {
            message = gate.unavailableReason
            return
        }
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.message = SpeechGate(onDeviceSupported: true, permissionGranted: false, recordingInProgress: false, localeIdentifier: self.localeIdentifier).unavailableReason
                    return
                }
                self.begin()
            }
        }
    }

    func stop(reason: String? = nil) {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let reason { message = reason }
    }

    func resetTranscript() {
        events = []
        lastTranscript = ""
        latestCommand = .unknown
    }

    private func begin() {
        stop()
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.supportsOnDeviceRecognition else {
            message = SpeechGate(onDeviceSupported: false, permissionGranted: true, recordingInProgress: false, localeIdentifier: localeIdentifier).unavailableReason
            return
        }
        self.recognizer = recognizer
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                message = "The microphone is not available for on-device recognition. Prompting continues at the speed you set."
                return
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            tapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stop(reason: "Speech recognition could not start. Prompting continues at the speed you set.")
            return
        }
        listening = true
        message = SpeechPrivacy.onDeviceNote
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.lastTranscript = text
                    guard result.isFinal else { return }
                    let event = TranscriptEvent(
                        transcript: text,
                        confidence: Double(result.bestTranscription.segments.last?.confidence ?? 0),
                        isFinal: true,
                        timestamp: Date().timeIntervalSince1970 * 1000,
                        source: "on-device"
                    )
                    self.events.append(event)
                    if self.events.count > 50 { self.events.removeFirst(self.events.count - 50) }
                    let command = VoiceCommands.parse(text)
                    if command != .unknown {
                        self.latestCommand = command
                        self.commandToken += 1
                    }
                }
                if error != nil {
                    self.stop(reason: "Speech recognition stopped. Cuevora did not switch to server recognition. You can keep using the speed control.")
                }
            }
        }
    }
}
