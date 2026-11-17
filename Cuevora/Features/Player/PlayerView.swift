import SwiftUI
import UIKit

struct PlayerView: View {
    let script: Script
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var playing = false
    @State private var speed = 30.0
    @State private var fontSize = 32.0
    @State private var mirror = false
    @State private var focus = true
    @State private var progress = 0.0
    @State private var resetToken = 0
    @State private var seekToken = 0
    @State private var seekTarget = 0.0
    @State private var lineSpacing = 1.4
    @State private var theme = 0
    @State private var countdownLength = 3
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    PromptScroll(text: script.content, playing: $playing, speed: speed, fontSize: fontSize, lineSpacing: lineSpacing, theme: theme, mirrored: mirror, resetToken: resetToken, seekToken: seekToken, seekTarget: seekTarget, progress: $progress)
                    if focus {
                        Rectangle().fill(theme == 1 ? .black.opacity(0.12) : .white.opacity(0.12)).frame(height: 48).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    if let countdown {
                        Text("\(countdown)").font(.system(size: 80, weight: .bold)).foregroundStyle(.white).padding(30).background(.black.opacity(0.75), in: Circle()).accessibilityLabel("Starting in \(countdown)")
                    }
                }
                .background(.black)
                ProgressView(value: progress).padding(.horizontal)
                HStack {
                    Button("Reset", systemImage: "backward.end") { cancelCountdown(); playing = false; resetToken += 1 }
                    Spacer()
                    Button("Back 10 percent", systemImage: "backward.fill") { seek(-0.1) }
                    Spacer()
                    Button(playing || countdown != nil ? "Pause" : "Play", systemImage: playing || countdown != nil ? "pause.fill" : "play.fill") { if playing || countdown != nil { cancelCountdown(); playing = false } else { startCountdown() } }
                    Spacer()
                    Button("Forward 10 percent", systemImage: "forward.fill") { seek(0.1) }
                    Spacer()
                    Menu("Options", systemImage: "slider.horizontal.3") {
                        Toggle("Mirror Text", isOn: $mirror)
                        Toggle("Focus Guide", isOn: $focus)
                        Picker("Theme", selection: $theme) { Text("Dark").tag(0); Text("Light").tag(1); Text("Studio").tag(2); Text("High Contrast").tag(3) }
                        Picker("Countdown", selection: $countdownLength) { Text("Off").tag(0); Text("3 seconds").tag(3); Text("5 seconds").tag(5); Text("10 seconds").tag(10) }
                    }
                }.labelStyle(.iconOnly).font(.title2).padding()
                VStack {
                    HStack { Text("Speed"); Slider(value: $speed, in: 5...100); Text("\(Int(speed))") }
                    HStack { Text("Text size"); Slider(value: $fontSize, in: 16...72); Text("\(Int(fontSize))") }
                    HStack { Text("Line spacing"); Slider(value: $lineSpacing, in: 1...3); Text(lineSpacing.formatted(.number.precision(.fractionLength(1)))) }
                }.font(.caption).padding([.horizontal, .bottom])
            }
            .navigationTitle(script.title.isEmpty ? "Teleprompter" : script.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onChange(of: scenePhase) { if scenePhase != .active { cancelCountdown(); playing = false } }
            .onChange(of: playing) { UIApplication.shared.isIdleTimerDisabled = playing }
            .onDisappear { cancelCountdown(); UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
    private func seek(_ amount: Double) {
        cancelCountdown(); playing = false
        seekTarget = min(1, max(0, progress + amount)); seekToken += 1
    }
    private func cancelCountdown() { countdownTask?.cancel(); countdownTask = nil; countdown = nil }
    private func startCountdown() {
        guard countdownLength > 0 else { playing = true; return }
        countdown = countdownLength
        countdownTask = Task { @MainActor in
            for remaining in stride(from: countdownLength, through: 1, by: -1) {
                countdown = remaining
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            countdown = nil; playing = true; countdownTask = nil
        }
    }
}

private struct PromptScroll: UIViewRepresentable {
    let text: String
    @Binding var playing: Bool
    let speed: Double
    let fontSize: Double
    let lineSpacing: Double
    let theme: Int
    let mirrored: Bool
    let resetToken: Int
    let seekToken: Int
    let seekTarget: Double
    @Binding var progress: Double

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.backgroundColor = .black
        scroll.delegate = context.coordinator
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 80),
            label.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -80),
            label.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        context.coordinator.label = label
        let link = CADisplayLink(target: context.coordinator, selector: #selector(Coordinator.tick(_:)))
        link.add(to: .main, forMode: .common)
        context.coordinator.link = link
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.scroll = scroll
        let styleKey = "\(fontSize)-\(lineSpacing)-\(theme)-\(text)"
        if c.styleKey != styleKey {
            let oldMaximum = max(0, scroll.contentSize.height - scroll.bounds.height)
            let fraction = oldMaximum > 0 ? max(0, min(1, scroll.contentOffset.y / oldMaximum)) : 0
            let colors: [(UIColor, UIColor)] = [(.black, .white), (.white, .black), (UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1), .systemTeal), (.black, .white)]
            let colorsForTheme = colors[min(max(theme, 0), colors.count - 1)]
            scroll.backgroundColor = colorsForTheme.0
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = fontSize * (lineSpacing - 1)
            c.label?.attributedText = NSAttributedString(string: text.isEmpty ? "This script is empty." : text, attributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: .medium), .foregroundColor: colorsForTheme.1, .paragraphStyle: paragraph])
            c.styleKey = styleKey
            scroll.layoutIfNeeded()
            scroll.setContentOffset(CGPoint(x: 0, y: fraction * max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
        }
        c.label?.transform = mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        if c.lastReset != resetToken { c.lastReset = resetToken; scroll.setContentOffset(.zero, animated: false) }
        if c.lastSeek != seekToken { c.lastSeek = seekToken; scroll.layoutIfNeeded(); let maximum = max(0, scroll.contentSize.height - scroll.bounds.height); scroll.setContentOffset(CGPoint(x: 0, y: maximum * seekTarget), animated: false) }
        if !playing { c.lastTime = nil }
    }
    static func dismantleUIView(_ view: UIScrollView, coordinator: Coordinator) { coordinator.link?.invalidate() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PromptScroll
        weak var scroll: UIScrollView?
        weak var label: UILabel?
        var link: CADisplayLink?
        var lastTime: CFTimeInterval?
        var lastReset = 0
        var lastSeek = 0
        var styleKey = ""
        init(_ parent: PromptScroll) { self.parent = parent }
        @objc func tick(_ link: CADisplayLink) {
            guard parent.playing, let scroll else { lastTime = nil; return }
            defer { lastTime = link.timestamp }
            guard let lastTime else { return }
            let maximum = max(0, scroll.contentSize.height - scroll.bounds.height)
            let next = min(maximum, scroll.contentOffset.y + parent.speed * min(link.timestamp - lastTime, 0.1))
            scroll.setContentOffset(CGPoint(x: 0, y: next), animated: false)
            if next >= maximum { DispatchQueue.main.async { self.parent.playing = false } }
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let value = maximum > 0 ? min(1, max(0, scrollView.contentOffset.y / maximum)) : 0
            DispatchQueue.main.async { self.parent.progress = value }
        }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { parent.playing = false }
    }
}
