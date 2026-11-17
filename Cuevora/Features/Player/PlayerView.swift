import SwiftUI
import UIKit

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    let script: Script
    var preferences: AppPreferences
    var initialProgress: Double

    @StateObject private var speech = OnDeviceSpeech()
    @State private var playing = false
    @State private var speed: Double
    @State private var fontSize: Double
    @State private var lineSpacing: Double
    @State private var mirror: Bool
    @State private var focus: Bool
    @State private var theme: PromptTheme
    @State private var countdownLength: Int
    @State private var progress = 0.0
    @State private var elapsed = 0.0
    @State private var remaining = 0.0
    @State private var resetToken = 0
    @State private var seekToken = 0
    @State private var seekProgress = 0.0
    @State private var nudgeToken = 0
    @State private var nudgePixels = 0.0
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var manualOverrideUntil = Date.distantPast
    @State private var speedNote = "Fixed speed"
    @State private var showRecording = false
    @State private var showRehearsal = false
    @State private var voiceOn: Bool
    @State private var previousIdleDisabled = false
    @State private var holdingAwake = false

    init(script: Script, preferences: AppPreferences, initialProgress: Double) {
        self.script = script
        self.preferences = preferences
        self.initialProgress = initialProgress
        _speed = State(initialValue: preferences.defaultSpeed)
        _fontSize = State(initialValue: preferences.defaultFontSize)
        _lineSpacing = State(initialValue: preferences.defaultLineSpacing)
        _mirror = State(initialValue: preferences.mirrorMode)
        _focus = State(initialValue: preferences.focusLineEnabled)
        _theme = State(initialValue: preferences.theme)
        _countdownLength = State(initialValue: preferences.countdownDuration)
        _voiceOn = State(initialValue: preferences.voiceControlsEnabled)
    }

    private var profile: ReadingProfile { preferences.profile }
    private var reducePlayerMotion: Bool { reduceMotion || profile.prefersReducedMotion }
    private var simpleControls: Bool { profile.simplifiesControls }
    private var effectiveFont: Double {
        var size = ReadingProfileStyle.fontSize(fontSize, profile: profile)
        if typeSize.isAccessibilitySize { size = max(size, ReadingProfile.lowVision.minimumFontSize) }
        return size
    }
    private var effectiveSpacing: Double { ReadingProfileStyle.lineSpacing(lineSpacing, profile: profile) }

    var body: some View {
        NavigationStack {
            ZStack {
                PromptScroll(
                    text: script.content,
                    markers: script.markers,
                    highlights: script.highlights,
                    playing: playing,
                    speed: speed,
                    fontSize: effectiveFont,
                    lineSpacing: effectiveSpacing,
                    theme: theme,
                    mirrored: mirror,
                    gesturesEnabled: preferences.gestureControlsEnabled && countdown == nil,
                    transparentBackground: false,
                    resetToken: resetToken,
                    seekToken: seekToken,
                    seekProgress: seekProgress,
                    nudgeToken: nudgeToken,
                    nudgePixels: nudgePixels,
                    progress: $progress,
                    elapsed: $elapsed,
                    remaining: $remaining,
                    onUserPause: pause,
                    onCompleted: pause,
                    onTapZone: handleTap,
                    onDoubleTap: togglePlay,
                    onPinch: { larger in
                        fontSize = min(72, max(16, fontSize + (larger ? 2 : -2)))
                        CuevoraHaptics.selection(enabled: preferences.hapticsEnabled)
                    }
                )
                if focus {
                    Rectangle()
                        .fill(theme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.18))
                        .frame(height: 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 140, height: 140)
                        .background(.ultraThinMaterial, in: Circle())
                        .accessibilityLabel("Starting in \(countdown)")
                }
            }
            .overlay(alignment: .top) { playerChrome }
            .safeAreaInset(edge: .bottom, spacing: 0) { transport }
            .background { KeyCommandHost(onKey: handleKey).frame(width: 0, height: 0) }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                seekProgress = initialProgress
                seekToken += 1
                if voiceOn { speech.start() }
            }
            .onDisappear {
                pause()
                speech.stop()
                releaseAwake()
                saveProgress()
            }
            .onChange(of: scenePhase) { if scenePhase != .active { pause() } }
            .onChange(of: playing) { updateAwake() }
            .onChange(of: speech.commandToken) { handleVoice(speech.latestCommand) }
            .onChange(of: speech.events.count) { updateAdaptiveSpeed() }
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView(script: script, preferences: preferences)
            }
            .sheet(isPresented: $showRehearsal) {
                RehearsalView(script: script, preferences: preferences)
            }
        }
    }

    private var ink: Color { theme == .light ? .black : .white }

    private var playerChrome: some View {
        HStack(spacing: 12) {
            roundButton("Done", systemImage: "xmark") { dismiss() }
            Text(script.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            roundButton("Record", systemImage: "video.fill") { openRecording() }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var transport: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .tint(CuevoraTheme.primary)
                .accessibilityLabel("Estimated progress")
                .accessibilityValue("\(Int(progress * 100)) percent")
            HStack {
                Text(ReadTime.clock(elapsed))
                Spacer()
                Text("About \(ReadTime.clock(remaining)) left")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            HStack(spacing: 18) {
                roundButton("Reset", systemImage: "backward.end.fill") { reset() }
                roundButton("Back 10 percent", systemImage: "gobackward.10") { seek(by: -0.1) }
                Button(playing || countdown != nil ? "Pause" : "Play", systemImage: playing || countdown != nil ? "pause.fill" : "play.fill") { togglePlay() }
                    .font(.title)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(CuevoraTheme.primary, in: Circle())
                    .accessibilityLabel(playing || countdown != nil ? "Pause" : "Play")
                roundButton("Forward 10 percent", systemImage: "goforward.10") { seek(by: 0.1) }
                optionsMenu
            }
            if !simpleControls { sliders }
            if let message = speech.message, voiceOn {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .foregroundStyle(ink)
    }

    private var optionsMenu: some View {
        Menu("Options", systemImage: "ellipsis") {
            Toggle("Mirror Text", isOn: $mirror)
            Toggle("Focus Guide", isOn: $focus)
            Picker("Theme", selection: $theme) {
                ForEach(PromptTheme.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Countdown", selection: $countdownLength) {
                Text("Off").tag(0); Text("3 seconds").tag(3); Text("5 seconds").tag(5); Text("10 seconds").tag(10)
            }
            Button("Rehearse", systemImage: "waveform") { showRehearsal = true }
            Button(voiceOn ? "Stop Voice Commands" : "Start Voice Commands") { toggleVoice() }
            Text("Tap the sides to skip. Double-tap to play or pause. Pinch to change text size.")
        }
        .font(.title3)
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
        .background(.ultraThinMaterial, in: Circle())
    }

    private var sliders: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Speed")
                Slider(value: $speed, in: 1...10, step: 0.5, onEditingChanged: { editing in
                    if editing {
                        speedNote = "Fixed speed"
                        manualOverrideUntil = Date().addingTimeInterval(8)
                    }
                })
                Text(speed.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                ForEach(PlaybackEngine.presets, id: \.self) { preset in
                    Button(preset.formatted(.number.precision(.fractionLength(0)))) {
                        speed = preset
                        manualOverrideUntil = Date().addingTimeInterval(8)
                    }
                    .buttonStyle(.bordered)
                    .tint(speed == preset ? CuevoraTheme.primary : .secondary)
                    .accessibilityLabel("Speed \(Int(preset))")
                }
                Text(speedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Text")
                Slider(value: $fontSize, in: 16...72, step: 1)
                Text("\(Int(fontSize))").monospacedDigit().frame(width: 32, alignment: .trailing)
            }
            HStack {
                Text("Spacing")
                Slider(value: $lineSpacing, in: 1...3, step: 0.1)
                Text(lineSpacing.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .font(.caption)
    }

    private func roundButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .accessibilityLabel(title)
    }

    private func handleTap(_ zone: Int) {
        if zone < 0 { seek(by: -0.1) }
        else if zone > 0 { seek(by: 0.1) }
        else { togglePlay() }
    }

    private func togglePlay() {
        if playing || countdown != nil { pause() } else { startCountdown() }
        CuevoraHaptics.impact(enabled: preferences.hapticsEnabled)
    }

    private func pause() {
        countdownTask?.cancel()
        countdown = nil
        playing = false
    }

    private func reset() {
        pause()
        elapsed = 0
        resetToken += 1
        saveProgress()
    }

    private func seek(by amount: Double) {
        pause()
        seekProgress = min(1, max(0, progress + amount))
        seekToken += 1
    }

    private func nudge(forward: Bool) {
        pause()
        let engine = PlaybackEngine(speed: speed)
        nudgePixels = (forward ? 1 : -1) * engine.pixelsPerSecond * 5
        nudgeToken += 1
    }

    private func startCountdown() {
        guard countdownLength > 0 else { playing = true; return }
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for remaining in stride(from: countdownLength, through: 1, by: -1) {
                countdown = remaining
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            countdown = nil
            playing = true
        }
    }

    private func toggleVoice() {
        voiceOn.toggle()
        preferences.voiceControlsEnabled = voiceOn
        if voiceOn { speech.start() } else { speech.stop(reason: "Voice commands are off. The speed stays where you set it.") }
        try? context.save()
    }

    private func handleVoice(_ command: VoiceCommand) {
        switch command {
        case .play: pause(); playing = true
        case .pause, .stop: pause()
        case .faster:
            speed = min(10, speed + 1)
            manualOverrideUntil = Date().addingTimeInterval(8)
        case .slower:
            speed = max(1, speed - 1)
            manualOverrideUntil = Date().addingTimeInterval(8)
        case .reset: reset()
        case .unknown: break
        }
        CuevoraHaptics.selection(enabled: preferences.hapticsEnabled)
    }

    private func updateAdaptiveSpeed() {
        guard preferences.adaptiveScrollEnabled else { speedNote = "Fixed speed"; return }
        let result = AdaptiveScroll.speed(
            baseSpeed: speed,
            targetWordsPerMinute: Double(preferences.wordsPerMinute),
            events: speech.events,
            now: Date().timeIntervalSince1970 * 1000,
            manualOverrideUntil: manualOverrideUntil.timeIntervalSince1970 * 1000
        )
        if result.reason == .adaptive {
            speed = result.speed
            speedNote = "Estimated from speech"
        } else {
            speedNote = "Fixed speed"
        }
    }

    private func openRecording() {
        pause()
        speech.setRecordingInProgress(true)
        speech.stop(reason: SpeechPrivacy.recordingContentionNote)
        showRecording = true
    }

    private func handleKey(_ input: String) {
        switch input {
        case " ": togglePlay()
        case UIKeyCommand.inputUpArrow: speed = min(10, speed + 0.5); manualOverrideUntil = Date().addingTimeInterval(8)
        case UIKeyCommand.inputDownArrow: speed = max(1, speed - 0.5); manualOverrideUntil = Date().addingTimeInterval(8)
        case UIKeyCommand.inputLeftArrow: nudge(forward: false)
        case UIKeyCommand.inputRightArrow: nudge(forward: true)
        case "m": mirror.toggle()
        case "f": focus.toggle()
        case "r": reset()
        case UIKeyCommand.inputEscape: dismiss()
        default: break
        }
    }

    private func updateAwake() {
        guard preferences.keepScreenAwake else { releaseAwake(); return }
        if playing && !holdingAwake {
            previousIdleDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            holdingAwake = true
        } else if !playing {
            releaseAwake()
        }
    }

    private func releaseAwake() {
        guard holdingAwake else { return }
        UIApplication.shared.isIdleTimerDisabled = previousIdleDisabled
        holdingAwake = false
    }

    private func saveProgress() {
        preferences.lastScriptUUID = script.identity
        preferences.lastProgress = progress
        try? context.save()
    }
}

private struct KeyCommandHost: UIViewRepresentable {
    var onKey: (String) -> Void

    func makeUIView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKey = onKey
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }

    func updateUIView(_ uiView: KeyView, context: Context) {
        uiView.onKey = onKey
        if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
    }
}

private final class KeyView: UIView {
    var onKey: ((String) -> Void)?
    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        let inputs = [" ", UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow, UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow, "m", "f", "r", UIKeyCommand.inputEscape]
        return inputs.map { UIKeyCommand(input: $0, modifierFlags: [], action: #selector(fire(_:))) }
    }

    @objc private func fire(_ command: UIKeyCommand) { onKey?(command.input ?? "") }
}
