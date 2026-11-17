import SwiftUI
import UIKit

struct PromptScroll: UIViewRepresentable {
    var text: String
    var markers: [Int]
    var highlights: [Int]
    var playing: Bool
    var speed: Double
    var fontSize: Double
    var lineSpacing: Double
    var theme: PromptTheme
    var mirrored: Bool
    var gesturesEnabled: Bool
    var transparentBackground: Bool
    var resetToken: Int
    var seekToken: Int
    var seekProgress: Double
    var nudgeToken: Int
    var nudgePixels: Double
    @Binding var progress: Double
    @Binding var elapsed: Double
    @Binding var remaining: Double
    var onUserPause: () -> Void
    var onCompleted: () -> Void
    var onTapZone: (Int) -> Void
    var onDoubleTap: () -> Void
    var onPinch: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.alwaysBounceVertical = true
        scroll.backgroundColor = .clear
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = true
        scroll.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 80),
            label.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -80),
            label.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        context.coordinator.label = label
        context.coordinator.scroll = scroll
        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinched(_:)))
        scroll.addGestureRecognizer(single)
        scroll.addGestureRecognizer(double)
        scroll.addGestureRecognizer(pinch)
        context.coordinator.tap = single
        context.coordinator.doubleTap = double
        context.coordinator.pinch = pinch
        let link = CADisplayLink(target: context.coordinator, selector: #selector(Coordinator.tick(_:)))
        link.add(to: .main, forMode: .common)
        context.coordinator.link = link
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.tap?.isEnabled = gesturesEnabled
        coordinator.doubleTap?.isEnabled = gesturesEnabled
        coordinator.pinch?.isEnabled = gesturesEnabled
        let styleKey = "\(fontSize)-\(lineSpacing)-\(theme.rawValue)-\(text)-\(markers)-\(highlights)-\(transparentBackground)"
        if coordinator.styleKey != styleKey {
            let fraction = coordinator.engine.progress
            applyStyle(scroll: scroll, label: coordinator.label)
            coordinator.styleKey = styleKey
            scroll.layoutIfNeeded()
            coordinator.engine.setMaximumOffset(maxOffset(scroll), preservingProgress: true)
            coordinator.engine.seek(toProgress: fraction)
            scroll.setContentOffset(CGPoint(x: 0, y: coordinator.engine.offset), animated: false)
        }
        coordinator.label?.transform = mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        if coordinator.lastReset != resetToken {
            coordinator.lastReset = resetToken
            coordinator.engine.reset()
            scroll.setContentOffset(.zero, animated: false)
        }
        if coordinator.lastSeek != seekToken {
            coordinator.lastSeek = seekToken
            scroll.layoutIfNeeded()
            coordinator.engine.maximumOffset = maxOffset(scroll)
            coordinator.engine.seek(toProgress: seekProgress)
            scroll.setContentOffset(CGPoint(x: 0, y: coordinator.engine.offset), animated: false)
        }
        if coordinator.lastNudge != nudgeToken {
            coordinator.lastNudge = nudgeToken
            scroll.layoutIfNeeded()
            coordinator.engine.maximumOffset = maxOffset(scroll)
            coordinator.engine.seekByPixels(nudgePixels)
            scroll.setContentOffset(CGPoint(x: 0, y: coordinator.engine.offset), animated: false)
        }
        coordinator.engine.speed = speed
        coordinator.engine.playing = playing
        if !playing { coordinator.lastTime = nil }
    }

    static func dismantleUIView(_ uiView: UIScrollView, coordinator: Coordinator) {
        coordinator.link?.invalidate()
    }

    private func applyStyle(scroll: UIScrollView, label: UILabel?) {
        let background = transparentBackground ? UIColor.clear : uiColor(theme.backgroundHex)
        let foreground = uiColor(theme.foregroundHex)
        scroll.backgroundColor = background
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * (lineSpacing - 1)
        paragraph.alignment = .natural
        paragraph.baseWritingDirection = .natural
        let string = NSMutableAttributedString()
        for line in PromptText.lines(content: text, markers: markers, highlights: highlights) {
            if line.sectionBreak {
                string.append(NSAttributedString(string: "——\n", attributes: [
                    .font: UIFont.systemFont(ofSize: max(12, fontSize * 0.45), weight: .regular),
                    .foregroundColor: foreground.withAlphaComponent(0.7),
                    .paragraphStyle: paragraph
                ]))
            }
            let font = UIFont.systemFont(ofSize: fontSize, weight: line.highlighted ? .bold : .medium)
            string.append(NSAttributedString(string: line.text + "\n", attributes: [
                .font: font,
                .foregroundColor: foreground,
                .paragraphStyle: paragraph
            ]))
        }
        label?.attributedText = string
        label?.accessibilityLabel = text.isEmpty ? "This script is empty." : text
    }

    private func maxOffset(_ scroll: UIScrollView) -> Double {
        max(0, scroll.contentSize.height - scroll.bounds.height)
    }

    private func uiColor(_ hex: String) -> UIColor {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PromptScroll
        weak var scroll: UIScrollView?
        weak var label: UILabel?
        var link: CADisplayLink?
        var tap: UITapGestureRecognizer?
        var doubleTap: UITapGestureRecognizer?
        var pinch: UIPinchGestureRecognizer?
        var engine = PlaybackEngine()
        var lastTime: CFTimeInterval?
        var lastReset = 0
        var lastSeek = 0
        var lastNudge = 0
        var styleKey = ""
        private var applying = false

        init(_ parent: PromptScroll) { self.parent = parent }

        @objc func tick(_ link: CADisplayLink) {
            guard let scroll else { return }
            engine.maximumOffset = max(0, scroll.contentSize.height - scroll.bounds.height)
            engine.speed = parent.speed
            engine.playing = parent.playing
            guard parent.playing else { lastTime = nil; return }
            defer { lastTime = link.timestamp }
            guard let delta = PlaybackTiming.delta(previous: lastTime, now: link.timestamp) else { return }
            let completed = engine.advance(delta: delta)
            applying = true
            scroll.setContentOffset(CGPoint(x: 0, y: engine.offset), animated: false)
            applying = false
            let progress = engine.progress
            let elapsed = engine.elapsed
            let remaining = engine.estimatedRemainingSeconds
            DispatchQueue.main.async {
                self.parent.progress = progress
                self.parent.elapsed = elapsed
                self.parent.remaining = remaining
                if completed { self.parent.onCompleted() }
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !applying else { return }
            let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            engine.maximumOffset = maximum
            engine.offset = scrollView.contentOffset.y
            let value = engine.progress
            let remaining = engine.estimatedRemainingSeconds
            DispatchQueue.main.async {
                self.parent.progress = value
                self.parent.remaining = remaining
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.onUserPause()
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let x = gesture.location(in: view).x
            let third = view.bounds.width / 3
            if x < third { parent.onTapZone(-1) }
            else if x > third * 2 { parent.onTapZone(1) }
            else { parent.onTapZone(0) }
        }

        @objc func doubleTapped() { parent.onDoubleTap() }

        @objc func pinched(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.state == .changed else { return }
            if gesture.scale > 1.08 {
                parent.onPinch(true)
                gesture.scale = 1
            } else if gesture.scale < 0.92 {
                parent.onPinch(false)
                gesture.scale = 1
            }
        }
    }
}
