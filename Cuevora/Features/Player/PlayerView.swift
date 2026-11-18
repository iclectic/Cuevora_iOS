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
    @State private var session: PlayerSession
    @State private var progress = 0.0
    @State private var elapsed = 0.0
    @State private var remaining = 0.0
    @State private var resetToken = 0
    @State private var seekToken = 0
    @State private var seekProgress = 0.0
    @State private var nudgeToken = 0
    @State private var nudgePixels = 0.0
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
        _session = State(initialValue: PlayerSession(
            speed: preferences.defaultSpeed,
            countdownLength: preferences.countdownDuration,
            mirror: preferences.mirrorMode,
            focus: preferences.focusLineEnabled,
            fontSize: preferences.defaultFontSize,
            lineSpacing: preferences.defaultLineSpacing,
            theme: preferences.theme,
            keepScreenAwake: preferences.keepScreenAwake
        ))
        _voiceOn = State(initialValue: preferences.voiceControlsEnabled)
    }

    private var profile: ReadingProfile { preferences.profile }
    private var accessibilityContext: AccessibilityContext {
        AccessibilityContext(
            profile: profile,
            reduceMotion: reduceMotion,
            increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled,
            differentiateWithoutColor: UIAccessibility.shouldDifferentiateWithoutColor,
            boldText: UIAccessibility.isBoldTextEnabled,
            accessibilityTextSize: typeSize.isAccessibilitySize,
            voiceOver: UIAccessibility.isVoiceOverRunning,
            switchControl: UIAccessibility.isSwitchControlRunning
        )
    }
    private var presentation: PromptPresentation {
        AccessibilityPresentation.prompt(
            baseFont: session.fontSize,
            baseSpacing: session.lineSpacing,
            theme: session.theme,
            gesturesEnabled: preferences.gestureControlsEnabled && session.countdownValue == nil,
            context: accessibilityContext
        )
    }
    private var playFeedback: ControlFeedback {
        AccessibilityPresentation.playFeedback(
            playing: session.playing || session.countdownValue != nil,
            hapticsEnabled: preferences.hapticsEnabled
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PromptScroll(
                    text: script.content,
                    markers: script.markers,
                    highlights: script.highlights,
                    playing: session.playing,
                    speed: session.speed,
                    fontSize: presentation.fontSize,
                    lineSpacing: presentation.lineSpacing,
                    theme: presentation.theme,
                    mirrored: session.mirror,
                    gesturesEnabled: presentation.gesturesEnabled,
                    reduceMotion: presentation.reduceMotion,
                    boldText: presentation.boldText,
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
                    onCompleted: {
                        session.finish()
                        updateAwake()
                    },
                    onTapZone: handleTap,
                    onDoubleTap: togglePlay,
                    onPinch: { larger in
                        session.fontSize = min(72, max(16, session.fontSize + (larger ? 2 : -2)))
                        CuevoraHaptics.selection(enabled: preferences.hapticsEnabled)
                    }
                )
                if session.focus {
                    Rectangle()
                        .fill(presentation.theme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.18))
                        .frame(height: presentation.focusThickness)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if let countdown = session.countdownValue {
                    Text("\(countdown)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 140, height: 140)
                        .background(.ultraThinMaterial, in: Circle())
                        .accessibilityLabel("Starting in \(countdown)")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { playerChrome }
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
            .onChange(of: scenePhase) {
                if scenePhase != .active {
                    pause()
                    saveProgress()
                }
            }
            .onChange(of: session.phase) { updateAwake() }
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

    private var ink: Color { session.theme == .light ? .black : .white }

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
            if presentation.showEstimates {
                HStack {
                    Text(ReadTime.clock(elapsed))
                    Spacer()
                    Text("About \(ReadTime.clock(remaining)) left")
                }
                .font((presentation.prominentEstimates ? Font.body : Font.caption).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
            if presentation.theme != session.theme {
                Text("High contrast is on, so the prompt uses the high-contrast theme.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 18) {
                roundButton("Reset", systemImage: "backward.end.fill") { reset() }
                roundButton("Back 10 percent", systemImage: "gobackward.10") { seek(by: -0.1) }
                Button(playFeedback.visibleLabel, systemImage: playFeedback.visibleLabel == "Pause" ? "pause.fill" : "play.fill") { togglePlay() }
                    .font(.title)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(CuevoraTheme.primary, in: Circle())
                    .accessibilityLabel(playFeedback.visibleLabel)
                roundButton("Forward 10 percent", systemImage: "goforward.10") { seek(by: 0.1) }
                optionsMenu
            }
            if presentation.showSpeedControl { speedControls }
            if presentation.showAppearanceControls { appearanceControls }
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
            Toggle("Mirror Text", isOn: $session.mirror)
            Toggle("Focus Guide", isOn: $session.focus)
            Picker("Theme", selection: $session.theme) {
                ForEach(PromptTheme.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Countdown", selection: $session.countdownLength) {
                Text("Off").tag(0); Text("3 seconds").tag(3); Text("5 seconds").tag(5); Text("10 seconds").tag(10)
            }
            Button("Rehearse", systemImage: "waveform") { showRehearsal = true }
            Button(voiceOn ? "Stop Voice Commands" : "Start Voice Commands") { toggleVoice() }
            Text(presentation.gesturesEnabled
                 ? "Tap the sides to skip. Double-tap to play or pause. Pinch to change text size."
                 : "Use the buttons. Gestures are off.")
        }
        .font(.title3)
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
        .background(.ultraThinMaterial, in: Circle())
    }

    private var speedControls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Speed")
                Slider(value: speedBinding, in: 1...10, step: 0.5, onEditingChanged: { editing in
                    if editing {
                        speedNote = "Fixed speed"
                        manualOverrideUntil = Date().addingTimeInterval(8)
                    }
                })
                Text(session.speed.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                ForEach(PlaybackEngine.presets, id: \.self) { preset in
                    let selected = session.speed == preset
                    Button {
                        session.setSpeed(preset)
                        manualOverrideUntil = Date().addingTimeInterval(8)
                    } label: {
                        HStack(spacing: 4) {
                            if presentation.selectionUsesShape && selected {
                                Image(systemName: "checkmark")
                            }
                            Text(preset.formatted(.number.precision(.fractionLength(0))))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? CuevoraTheme.primary : .secondary)
                    .accessibilityLabel("Speed \(Int(preset))")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Text(speedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var appearanceControls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Text")
                Slider(value: $session.fontSize, in: 16...72, step: 1)
                Text("\(Int(session.fontSize))").monospacedDigit().frame(width: 32, alignment: .trailing)
            }
            HStack {
                Text("Spacing")
                Slider(value: $session.lineSpacing, in: 1...3, step: 0.1)
                Text(session.lineSpacing.formatted(.number.precision(.fractionLength(1))))
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

    private var speedBinding: Binding<Double> {
        Binding(get: { session.speed }, set: { session.setSpeed($0) })
    }

    private func handleTap(_ zone: Int) {
        if zone < 0 { seek(by: -0.1) }
        else if zone > 0 { seek(by: 0.1) }
        else { togglePlay() }
    }

    private func togglePlay() {
        let wasActive = session.playing || session.countdownValue != nil
        session.toggle(at: .now)
        if wasActive {
            countdownTask?.cancel()
        } else if session.countdownValue != nil {
            watchCountdown()
        }
        updateAwake()
        CuevoraHaptics.impact(enabled: playFeedback.haptics)
    }

    private func pause() {
        countdownTask?.cancel()
        session.pause()
        updateAwake()
    }

    private func reset() {
        countdownTask?.cancel()
        session.reset()
        elapsed = 0
        resetToken += 1
        updateAwake()
        saveProgress()
    }

    private func seek(by amount: Double) {
        pause()
        seekProgress = min(1, max(0, progress + amount))
        seekToken += 1
    }

    private func nudge(forward: Bool) {
        pause()
        let engine = PlaybackEngine(speed: session.speed)
        nudgePixels = (forward ? 1 : -1) * engine.pixelsPerSecond * 5
        nudgeToken += 1
    }

    private func watchCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while !Task.isCancelled, session.countdownValue != nil {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
                session.advanceCountdown(to: .now)
            }
            updateAwake()
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
        case .play: session.playImmediately(); updateAwake()
        case .pause, .stop: pause()
        case .faster:
            session.adjustSpeed(by: 1)
            manualOverrideUntil = Date().addingTimeInterval(8)
        case .slower:
            session.adjustSpeed(by: -1)
            manualOverrideUntil = Date().addingTimeInterval(8)
        case .reset: reset()
        case .unknown: break
        }
        CuevoraHaptics.selection(enabled: preferences.hapticsEnabled)
    }

    private func updateAdaptiveSpeed() {
        guard preferences.adaptiveScrollEnabled else { speedNote = "Fixed speed"; return }
        let result = AdaptiveScroll.speed(
            baseSpeed: session.speed,
            targetWordsPerMinute: Double(preferences.wordsPerMinute),
            events: speech.events,
            now: Date().timeIntervalSince1970 * 1000,
            manualOverrideUntil: manualOverrideUntil.timeIntervalSince1970 * 1000
        )
        if result.reason == .adaptive {
            session.setSpeed(result.speed)
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
        let name: String
        switch input {
        case " ": name = "space"
        case UIKeyCommand.inputUpArrow: name = "up"
        case UIKeyCommand.inputDownArrow: name = "down"
        case UIKeyCommand.inputLeftArrow: name = "left"
        case UIKeyCommand.inputRightArrow: name = "right"
        case UIKeyCommand.inputEscape: name = "escape"
        default: name = input
        }
        guard let key = PlayerSession.Key(named: name) else { return }
        switch key {
        case .togglePlay: togglePlay()
        case .faster, .slower:
            session.perform(key, at: .now)
            manualOverrideUntil = Date().addingTimeInterval(8)
        case .back: nudge(forward: false)
        case .forward: nudge(forward: true)
        case .mirror, .focus: session.perform(key, at: .now)
        case .reset: reset()
        case .close: dismiss()
        }
    }

    private func updateAwake() {
        guard preferences.keepScreenAwake else { releaseAwake(); return }
        if session.awake && !holdingAwake {
            previousIdleDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            holdingAwake = true
        } else if !session.awake {
            releaseAwake()
        }
    }

    private func releaseAwake() {
        guard holdingAwake else { return }
        UIApplication.shared.isIdleTimerDisabled = previousIdleDisabled
        holdingAwake = false
    }

    private func saveProgress() {
        let clamped = min(1, max(0, progress))
        script.readingProgress = clamped
        preferences.lastScriptUUID = script.identity
        preferences.lastProgress = clamped
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
