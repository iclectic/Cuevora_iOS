import Foundation

/// Deterministic teleprompter motion. Speed uses the reference scale of 1...10,
/// where one unit is 20 points per second. Frame deltas are clamped so a stalled
/// display link cannot jump the script forward.
public struct PlaybackEngine: Equatable {
    public static let pixelsPerSpeedUnit = 20.0
    public static let minimumSpeed = 1.0
    public static let maximumSpeed = 10.0
    public static let endThreshold = 1.0
    public static let maximumFrameDelta = 0.1
    public static let presets: [Double] = [1, 3, 5, 8]

    public var offset: Double
    public var maximumOffset: Double
    public var speed: Double
    public var playing: Bool
    public var elapsed: Double
    private var remainder: Double

    public init(speed: Double = 3) {
        offset = 0
        maximumOffset = 0
        self.speed = speed
        playing = false
        elapsed = 0
        remainder = 0
    }

    public var clampedSpeed: Double {
        min(Self.maximumSpeed, max(Self.minimumSpeed, speed))
    }

    public var pixelsPerSecond: Double {
        clampedSpeed * Self.pixelsPerSpeedUnit
    }

    public var progress: Double {
        guard maximumOffset > 0 else { return 0 }
        return min(1, max(0, offset / maximumOffset))
    }

    /// Scroll-based estimate. Callers must label it as an estimate.
    public var estimatedRemainingSeconds: Double {
        guard pixelsPerSecond > 0 else { return 0 }
        return max(0, (maximumOffset - offset) / pixelsPerSecond)
    }

    public mutating func setMaximumOffset(_ value: Double, preservingProgress: Bool) {
        let fraction = progress
        maximumOffset = max(0, value)
        offset = preservingProgress ? fraction * maximumOffset : min(offset, maximumOffset)
    }

    /// Advances playback. Returns true when the script reaches the end.
    @discardableResult
    public mutating func advance(delta: Double) -> Bool {
        guard playing else { return false }
        let clampedDelta = min(max(0, delta), Self.maximumFrameDelta)
        elapsed += clampedDelta
        let movement = pixelsPerSecond * clampedDelta + remainder
        let before = offset
        let next = min(maximumOffset, max(0, before + movement))
        offset = next
        remainder = movement - (next - before)
        if maximumOffset > 0, offset >= maximumOffset - Self.endThreshold {
            offset = maximumOffset
            playing = false
            remainder = 0
            return true
        }
        return false
    }

    public mutating func play() { playing = true }
    public mutating func pause() { playing = false }

    public mutating func reset() {
        offset = 0
        elapsed = 0
        remainder = 0
        playing = false
    }

    public mutating func seek(toProgress value: Double) {
        offset = maximumOffset * min(1, max(0, value))
        remainder = 0
    }

    public mutating func seekByPixels(_ pixels: Double) {
        offset = min(maximumOffset, max(0, offset + pixels))
        remainder = 0
    }

    /// Five seconds of motion at the current speed, matching the reference skip.
    public mutating func skip(forward: Bool) {
        let distance = pixelsPerSecond * 5
        seekByPixels(forward ? distance : -distance)
    }

    public mutating func adjustSpeed(by delta: Double) {
        speed = min(Self.maximumSpeed, max(Self.minimumSpeed, (speed + delta) * 2).rounded() / 2)
    }
}

public enum ReadTime {
    public static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace }.count
    }

    public static func seconds(text: String, wordsPerMinute: Int) -> Int {
        let rate = max(1, wordsPerMinute)
        return Int(ceil(Double(wordCount(text)) / Double(rate) * 60))
    }

    public static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
