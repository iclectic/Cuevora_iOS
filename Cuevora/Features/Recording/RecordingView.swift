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
            stage
                .overlay {
                    if case let .countdown(seconds) = capture.phase {
                        Text("\(seconds)")
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 140, height: 140)
                            .background(.ultraThinMaterial, in: Circle())
                            .accessibilityLabel("Recording starts in \(seconds)")
                    }
                }
                .overlay(alignment: .top) { status }
                .safeAreaInset(edge: .bottom, spacing: 0) { controls }
                .background(.black)
                .toolbar(.hidden, for: .navigationBar)
            .onAppear { capture.prepare(quality: preferences.recordingQuality) }
            .onDisappear { playing = false; capture.shutdown() }
            .onChange(of: scenePhase) {
                if scenePhase != .active {
                    playing = false
                    capture.backgrounded()
                }
            }
            .onChange(of: capture.savedTake) { rememberTake() }
            .onChange(of: capture.pendingLibraryTakes) { adoptRecoveredTakes() }
            .onChange(of: capture.discardedFileName) { deleteDiscarded() }
            .sheet(isPresented: $showShare) {
                if let url = capture.previewURL {
                    ShareSheet(url: url) { result in
                        capture.noteShare(result)
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
                let stage = PromptStage.stage(
                    split: true,
                    width: geo.size.width,
                    height: geo.size.height,
                    regularWidth: sizeClass == .regular
                )
                let cameraView = cameraPreview
                let promptView = prompt
                switch stage {
                case .splitSide(let fraction):
                    HStack(spacing: 0) { cameraView.frame(width: geo.size.width * fraction); promptView }
                case .splitStack(let fraction):
                    VStack(spacing: 0) { cameraView.frame(height: geo.size.height * fraction); promptView }
                case .overlay:
                    ZStack { cameraView; promptView }
                }
            }
        } else {
            ZStack { cameraPreview; prompt }
        }
    }

    private var cameraPreview: some View {
        CameraPreview(session: capture.session, mirrored: CaptureMirror.previewMirrored(frontCamera: capture.usingFrontCamera))
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
        HStack(spacing: 12) {
            Button("Close", systemImage: "xmark") { capture.shutdown(); dismiss() }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .accessibilityLabel("Close")
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText).font(.subheadline.weight(.semibold))
                Text(capture.message ?? "The script stays on screen. It is not part of the video.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)
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
        VStack(spacing: 16) {
            HStack {
                Text("Speed")
                    .font(.caption)
                Slider(value: $speed, in: 1...10, step: 0.5)
                    .tint(CuevoraTheme.primary)
                Text(speed.formatted(.number.precision(.fractionLength(1))))
                    .font(.caption.monospacedDigit())
                    .frame(width: 32, alignment: .trailing)
            }
            HStack(spacing: 22) {
                Button(playing ? "Pause Prompt" : "Play Prompt", systemImage: playing ? "pause.fill" : "play.fill") { playing.toggle() }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .accessibilityLabel(playing ? "Pause Prompt" : "Play Prompt")
                recordButton
                Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath") { capture.switchCamera() }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .disabled(capture.phase == .recording || isCountdown)
                    .accessibilityLabel("Switch Camera")
            }
            HStack(spacing: 16) {
                Button(split ? "Overlay" : "Split View", systemImage: split ? "rectangle.inset.filled" : "rectangle.split.2x1") { split.toggle() }
                    .accessibilityLabel(split ? "Overlay" : "Split View")
                Button("Share", systemImage: "square.and.arrow.up") { showShare = true }
                    .disabled(capture.previewURL == nil)
                    .accessibilityLabel("Share")
                Button("Save to Photos", systemImage: "photo") { capture.saveCurrentToPhotos() }
                    .disabled(capture.previewURL == nil)
                    .accessibilityLabel("Save to Photos")
                Button("Delete Take", systemImage: "trash", role: .destructive) { capture.discard() }
                    .disabled(capture.previewURL == nil)
                    .accessibilityLabel("Delete Take")
            }
            .labelStyle(.iconOnly)
            .font(.body)
            .buttonStyle(.borderless)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var recordButton: some View {
        Button {
            if capture.phase == .recording || isCountdown {
                if isCountdown { capture.cancelCountdown() } else { playing = false; capture.stop() }
            } else {
                capture.requestStart(countdown: preferences.countdownDuration, quality: preferences.recordingQuality)
            }
        } label: {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4)
                if capture.phase == .recording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CuevoraTheme.amber)
                        .padding(22)
                } else {
                    Circle().fill(CuevoraTheme.amber).padding(8)
                }
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(capture.phase == .recording ? "Stop" : "Record")
        .accessibilityHint("Asks for the camera and microphone only when you start.")
    }

    private var isCountdown: Bool {
        if case .countdown = capture.phase { return true }
        return false
    }

    private func rememberTake() {
        guard let take = capture.savedTake, rememberedFile != take.fileName else { return }
        insert(take, title: script.displayTitle, linkScript: true)
        rememberedFile = take.fileName
    }

    private func adoptRecoveredTakes() {
        for take in capture.pendingLibraryTakes {
            insert(take, title: "Recovered take", linkScript: false)
        }
    }

    private func insert(_ take: SavedTake, title: String, linkScript: Bool) {
        let name = take.fileName
        let descriptor = FetchDescriptor<RecordingItem>(predicate: #Predicate { $0.fileName == name })
        guard ((try? context.fetch(descriptor)) ?? []).isEmpty else { return }
        let item = RecordingItem(fileName: name, scriptTitle: title, duration: take.duration, partial: take.partial, recoverable: take.recoverable)
        if linkScript { item.script = script }
        context.insert(item)
        try? context.save()
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
    var onComplete: (ShareResult) -> Void

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
    var onComplete: ((ShareResult) -> Void)?
    private var presentedShare = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !presentedShare, let url else { return }
        presentedShare = true
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        activity.completionWithItemsHandler = { _, completed, _, error in
            if error != nil {
                self.onComplete?(.failed)
            } else if completed {
                self.onComplete?(.finished)
            } else {
                self.onComplete?(.cancelled)
            }
        }
        present(activity, animated: true)
    }
}
