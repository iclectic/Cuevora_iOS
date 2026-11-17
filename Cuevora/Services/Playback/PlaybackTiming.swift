import Foundation

/// Turns display timestamps into the frame interval the prompter is allowed to use.
/// The first sample returns nil so a clock that was stopped cannot throw the script forward.
enum PlaybackTiming {
    static func delta(previous: TimeInterval?, now: TimeInterval) -> Double? {
        guard let previous else { return nil }
        return PlayerSession.clampedDelta(now - previous)
    }
}
