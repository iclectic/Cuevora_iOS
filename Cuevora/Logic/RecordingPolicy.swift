import Foundation

public enum ShareResult: Equatable {
    case finished, cancelled, failed

    public var action: RecordingAction {
        switch self {
        case .finished: .shareFinished
        case .cancelled: .shareCancelled
        case .failed: .shareFailed
        }
    }
}

public enum CaptureInterruptionKind: Equatable {
    case audioInUse, videoInUse, background, multitasking, unknown

    public var message: String {
        switch self {
        case .audioInUse: "The microphone is being used by another app."
        case .videoInUse: "The camera is being used by another app."
        case .background: "The camera stopped because Cuevora was in the background."
        case .multitasking: "The camera stopped during multitasking."
        case .unknown: "Recording was interrupted."
        }
    }
}

public enum CaptureMirror {
    public static func previewMirrored(frontCamera: Bool) -> Bool { frontCamera }
    public static let recordedFileMirrored = false
}

public enum PromptStage: Equatable {
    case overlay
    case splitSide(cameraFraction: Double)
    case splitStack(cameraFraction: Double)

    public static func stage(split: Bool, width: Double, height: Double, regularWidth: Bool) -> PromptStage {
        guard split else { return .overlay }
        if width > height || regularWidth { return .splitSide(cameraFraction: 0.42) }
        return .splitStack(cameraFraction: 0.34)
    }
}

public struct RecordingCountdown: Equatable {
    public private(set) var remaining: Int?
    public private(set) var endsAt: Date?

    public init() {}

    public enum Step: Equatable {
        case waiting(Int)
        case finished
        case inactive
    }

    public mutating func start(seconds: Int, at date: Date) {
        guard seconds > 0 else {
            remaining = nil
            endsAt = nil
            return
        }
        remaining = seconds
        endsAt = date.addingTimeInterval(TimeInterval(seconds))
    }

    public mutating func advance(to date: Date) -> Step {
        guard let endsAt else { return .inactive }
        let left = Int(ceil(endsAt.timeIntervalSince(date)))
        if left <= 0 {
            remaining = nil
            self.endsAt = nil
            return .finished
        }
        remaining = left
        return .waiting(left)
    }

    public mutating func cancel() {
        remaining = nil
        endsAt = nil
    }
}

public struct RecoveredTake: Equatable {
    public var fileName: String
    public var duration: Double
    public var partial: Bool
    public var recoverable: Bool
    public var phase: RecordingPhase
    public var message: String

    public init(fileName: String, duration: Double, partial: Bool, recoverable: Bool, phase: RecordingPhase, message: String) {
        self.fileName = fileName
        self.duration = duration
        self.partial = partial
        self.recoverable = recoverable
        self.phase = phase
        self.message = message
    }
}

public enum TakeRecovery {
    public static func decide(fileName: String, playable: Bool, duration: Double) -> RecoveredTake {
        let finite = duration.isFinite ? max(0, duration) : 0
        let recoverable = playable && finite > 0
        if recoverable {
            return RecoveredTake(
                fileName: fileName,
                duration: finite,
                partial: true,
                recoverable: true,
                phase: .preview(partial: true),
                message: "A partial take was restored."
            )
        }
        return RecoveredTake(
            fileName: fileName,
            duration: finite,
            partial: true,
            recoverable: false,
            phase: .failed("A previous recording could not be recovered. The file is still available to share or delete."),
            message: "Recovery failed"
        )
    }
}

public enum RecordingCatalog {
    public static func shouldAdopt(fileName: String, existing: some Sequence<String>) -> Bool {
        !existing.contains(fileName)
    }

    public static func keptNames(afterDeleting name: String, from names: [String]) -> [String] {
        names.filter { $0 != name }
    }
}
