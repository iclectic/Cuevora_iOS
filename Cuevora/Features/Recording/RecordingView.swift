import AVKit
import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    let script: Script
    var preferences: AppPreferences

    @StateObject private var capture = CaptureSessionController()
    @State private var split = false
    @State private var playing = false
    @State private var speed: Double
    @State private var progress = 0.0
    @State private var promptElapsed = 0.0
    @State private var remaining = 0.0
    @State private var resetToken = 0
    @State private var seekToken = 0
    @State private var seekProgress = 0.0
    @State private var nudgeToken = 0
    @State private var showShare = false
    @State private var rememberedFile: String?

    init(script: Script, preferences: AppPreferences) {
        self.script = script
        self.preferences = preferences
        _speed = State(initialValue: preferences.defaultSpeed)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stage
                    .overlay {
                        if case let .countdown(seconds) = capture.phase {
                            Text("\(seconds)")
                                .font(.system(size: 72, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(24)
                                .background(.black.opacity(0.72), in: Circle())
                                .accessibilityLabel("Recording starts in \(seconds)")
                        }
                    }
                status
                controls
            }
            .background(.black)
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Close") { capture.shutdown(); dismiss() }
            }
            .onAppear { capture.prepare(quality: preferences.recordingQuality) }
            .onDisappear { playing = false; capture.shutdown() }
            .onChange(of: scenePhase) {
                if scenePhase != .active {
                    playing = false
                    capture.backgrounded()
                }
            }
            .onChange(of: capture.savedTake) { rememberTake() }
            .onChange(of: capture.discardedFileName) { deleteDiscarded() }
            .sheet(isPresented: $showShare) {
                if let url = capture.previewURL {
                    ShareSheet(url: url) { completed in
                        if !completed { capture.noteShareFailed() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stage: some View {
        if case .preview = capture.phase, let url = capture.previewURL {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if split {
            GeometryReader { geo in
                let wide = geo.size.width > geo.size.height || sizeClass == .regular
                let cameraView = cameraPreview
                let promptView = prompt
                if wide {
                    HStack(spacing: 0) { cameraView.frame(width: geo.size.width * 0.42); promptView }
                } else {
                    VStack(spacing: 0) { cameraView.frame(height: geo.size.height * 0.34); promptView }
                }
            }
        } else {
            ZStack { cameraPreview; prompt }
        }
    }

    private var cameraPreview: some View {
        CameraPreview(session: capture.session, mirrored: capture.usingFrontCamera)
            .accessibilityLabel(capture.usingFrontCamera ? "Front camera preview" : "Rear camera preview")
    }

    private var prompt: some View {
        PromptScroll(
            text: script.content,
            markers: script.markers,
            highlights: script.highlights,
            playing: playing,
            speed: speed,
            fontSize: min(preferences.defaultFontSize, 32),
            lineSpacing: preferences.defaultLineSpacing,
            theme: preferences.theme,
            mirrored: false,
            gesturesEnabled: false,
            transparentBackground: !split,
            resetToken: resetToken,
            seekToken: seekToken,
            seekProgress: seekProgress,
            nudgeToken: nudgeToken,
            nudgePixels: 0,
            progress: $progress,
            elapsed: $promptElapsed,
            remaining: $remaining,
            onUserPause: { playing = false },
            onCompleted: { playing = false },
            onTapZone: { _ in },
            onDoubleTap: {},
            onPinch: { _ in }
        )
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statusText).font(.subheadline).foregroundStyle(.white)
            Text("The script is an overlay. It is not part of the video.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            if let message = capture.message {
                Text(message).font(.caption).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var statusText: String {
        switch capture.phase {
        case .idle: "Ready"
        case .countdown: "Get ready"
        case .recording: "Recording \(ReadTime.clock(capture.elapsed))"
        case .stopping: "Saving the take"
        case let .preview(partial): partial ? "Partial take ready" : "Take ready"
        case let .failed(message): message
        }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button(playing ? "Pause Prompt" : "Play Prompt") { playing.toggle() }
                Button(capture.phase == .recording ? "Stop" : "Record") {
                    if capture.phase == .recording || isCountdown {
                        if isCountdown { capture.cancelCountdown() } else { playing = false; capture.stop() }
                    } else {
                        capture.requestStart(countdown: preferences.countdownDuration, quality: preferences.recordingQuality)
                    }
                }
                .accessibilityHint("Asks for the camera and microphone only when you start.")
                Button("Switch Camera") { capture.switchCamera() }
                    .disabled(capture.phase == .recording || isCountdown)
            }
            HStack {
                Button(split ? "Overlay" : "Split View") { split.toggle() }
                Button("Share") { showShare = true }.disabled(capture.previewURL == nil)
                Button("Save to Photos") { capture.saveCurrentToPhotos() }.disabled(capture.previewURL == nil)
                Button("Delete Take", role: .destructive) { capture.discard() }.disabled(capture.previewURL == nil)
            }
            HStack {
                Text("Speed")
                Slider(value: $speed, in: 1...10, step: 0.5)
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
        .foregroundStyle(.white)
        .padding()
    }

    private var isCountdown: Bool {
        if case .countdown = capture.phase { return true }
        return false
    }

    private func rememberTake() {
        guard let take = capture.savedTake, rememberedFile != take.fileName else { return }
        let item = RecordingItem(fileName: take.fileName, scriptTitle: script.displayTitle, duration: take.duration, partial: take.partial, recoverable: take.recoverable)
        item.script = script
        context.insert(item)
        try? context.save()
        rememberedFile = take.fileName
    }

    private func deleteDiscarded() {
        guard let name = capture.discardedFileName else { return }
        let descriptor = FetchDescriptor<RecordingItem>(predicate: #Predicate { $0.fileName == name })
        for item in (try? context.fetch(descriptor)) ?? [] { context.delete(item) }
        try? context.save()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var url: URL
    var onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> ShareHost {
        let host = ShareHost()
        host.url = url
        host.onComplete = onComplete
        return host
    }

    func updateUIViewController(_ host: ShareHost, context: Context) {
        host.url = url
        host.onComplete = onComplete
    }
}

final class ShareHost: UIViewController {
    var url: URL?
    var onComplete: ((Bool) -> Void)?
    private var presentedShare = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !presentedShare, let url else { return }
        presentedShare = true
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        activity.completionWithItemsHandler = { _, completed, _, error in
            self.onComplete?(completed && error == nil)
        }
        present(activity, animated: true)
    }
}
