import Foundation

/// Prompter controls that do not depend on the screen. Motion stays in `PlaybackEngine`.
public struct PlayerSession: Equatable {
    public static func clampedDelta(_ delta: Double) -> Double {
        min(max(0, delta), PlaybackEngine.maximumFrameDelta)
    }

    public enum Phase: Equatable {
        case ready
        case counting(Int)
        case playing
        case paused
        case finished
    }

    public enum Key: Equatable {
        case togglePlay
        case faster
        case slower
        case back
        case forward
        case mirror
        case focus
        case reset
        case close

        public init?(named input: String) {
            switch input {
            case "space": self = .togglePlay
            case "up": self = .faster
            case "down": self = .slower
            case "left": self = .back
            case "right": self = .forward
            case "m": self = .mirror
            case "f": self = .focus
            case "r": self = .reset
            case "escape": self = .close
            default: return nil
            }
        }
    }

    public var phase: Phase
    public var speed: Double
    public var countdownLength: Int
    public var mirror: Bool
    public var focus: Bool
    public var fontSize: Double
    public var lineSpacing: Double
    public var theme: PromptTheme
    public var keepScreenAwake: Bool
    public private(set) var countdownEndsAt: Date?

    public init(speed: Double = 3, countdownLength: Int = 3, mirror: Bool = false, focus: Bool = true, fontSize: Double = 32, lineSpacing: Double = 1.6, theme: PromptTheme = .dark, keepScreenAwake: Bool = true) {
        phase = .ready
        self.speed = min(PlaybackEngine.maximumSpeed, max(PlaybackEngine.minimumSpeed, speed))
        self.countdownLength = countdownLength
        self.mirror = mirror
        self.focus = focus
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.theme = theme
        self.keepScreenAwake = keepScreenAwake
    }

    public var playing: Bool { phase == .playing }
    public var awake: Bool { phase == .playing && keepScreenAwake }
    public var countdownValue: Int? {
        if case .counting(let value) = phase { return value }
        return nil
    }

    public mutating func toggle(at date: Date) {
        switch phase {
        case .playing, .counting:
            pause()
        case .ready, .paused, .finished:
            begin(at: date)
        }
    }

    public mutating func playImmediately() {
        countdownEndsAt = nil
        phase = .playing
    }

    public mutating func pause() {
        countdownEndsAt = nil
        if phase != .finished { phase = phase == .ready ? .ready : .paused }
    }

    public mutating func enterBackground() {
        pause()
    }

    public mutating func advanceCountdown(to date: Date) {
        guard case .counting = phase, let countdownEndsAt else { return }
        let left = Int(ceil(countdownEndsAt.timeIntervalSince(date)))
        if left <= 0 {
            self.countdownEndsAt = nil
            phase = .playing
        } else {
            phase = .counting(left)
        }
    }

    public mutating func setSpeed(_ value: Double) {
        speed = min(PlaybackEngine.maximumSpeed, max(PlaybackEngine.minimumSpeed, value))
    }

    public mutating func adjustSpeed(by delta: Double) {
        setSpeed(speed + delta)
    }

    public mutating func perform(_ key: Key, at date: Date) {
        switch key {
        case .togglePlay: toggle(at: date)
        case .faster: adjustSpeed(by: 0.5)
        case .slower: adjustSpeed(by: -0.5)
        case .back, .forward, .close: break
        case .mirror: mirror.toggle()
        case .focus: focus.toggle()
        case .reset: reset()
        }
    }

    public mutating func reset() {
        countdownEndsAt = nil
        phase = .ready
    }

    public mutating func finish() {
        countdownEndsAt = nil
        phase = .finished
    }

    /// A display frame may move the script only while it is playing.
    public func acceptsFrame() -> Bool { phase == .playing }

    private mutating func begin(at date: Date) {
        let length = max(0, countdownLength)
        if length == 0 {
            phase = .playing
            countdownEndsAt = nil
        } else {
            phase = .counting(length)
            countdownEndsAt = date.addingTimeInterval(TimeInterval(length))
        }
    }
}

public enum PromptTypography {
    public static func fontSize(base: Double, profile: ReadingProfile, accessibilitySize: Bool) -> Double {
        var size = ReadingProfileStyle.fontSize(base, profile: profile)
        if accessibilitySize { size = max(size, ReadingProfile.lowVision.minimumFontSize) }
        return size
    }

    public static func lineSpacing(base: Double, profile: ReadingProfile) -> Double {
        ReadingProfileStyle.lineSpacing(base, profile: profile)
    }
}
