import Foundation

public enum CaptureAccess: String, Equatable {
    case unknown, granted, denied, unavailable
}

public struct CapturePermissions: Equatable {
    public var camera: CaptureAccess
    public var microphone: CaptureAccess

    public init(camera: CaptureAccess, microphone: CaptureAccess) {
        self.camera = camera
        self.microphone = microphone
    }

    public var canRecord: Bool { camera == .granted && microphone == .granted }
}

public enum RecordingPhase: Equatable {
    case idle
    case countdown(Int)
    case recording
    case stopping(partial: Bool)
    case preview(partial: Bool)
    case failed(String)
}

public enum RecordingAction: Equatable {
    case requestStart(countdown: Int, permissions: CapturePermissions, freeBytes: Int64, thermalSerious: Bool)
    case countdownFinished
    case cancelCountdown
    case stop
    case interrupted(String)
    case backgrounded
    case fileReady(partial: Bool)
    case fileFailed(String)
    case discardPreview
    case shareFinished
    case shareCancelled
    case shareFailed
    case photosSaved
    case photosDenied
    case photosFailed
    case audioRouteChanged
    case storageLow
    case switchCamera
}

public struct RecordingTransition: Equatable {
    public var phase: RecordingPhase
    public var finalizePartial: Bool
    public var deleteFile: Bool
    public var allowCameraSwitch: Bool
    public var message: String?

    public init(phase: RecordingPhase, finalizePartial: Bool = false, deleteFile: Bool = false, allowCameraSwitch: Bool = false, message: String? = nil) {
        self.phase = phase
        self.finalizePartial = finalizePartial
        self.deleteFile = deleteFile
        self.allowCameraSwitch = allowCameraSwitch
        self.message = message
    }
}

public enum RecordingReducer {
    public static let minimumFreeBytes: Int64 = 200_000_000

    public static func reduce(phase: RecordingPhase, action: RecordingAction) -> RecordingTransition {
        switch action {
        case let .requestStart(countdown, permissions, freeBytes, thermalSerious):
            guard !isCapturing(phase) else {
                return RecordingTransition(phase: phase, message: "A recording is already in progress.")
            }
            if permissions.camera == .denied || permissions.microphone == .denied {
                return RecordingTransition(phase: .failed("Camera or microphone access is off. You can allow both in Settings and try again. Nothing was recorded."), message: "Permission denied")
            }
            if permissions.camera == .unavailable || permissions.microphone == .unavailable {
                return RecordingTransition(phase: .failed("This device does not have a camera and microphone Cuevora can use."), message: "Hardware unavailable")
            }
            if permissions.camera != .granted || permissions.microphone != .granted {
                return RecordingTransition(phase: phase, message: "Waiting for camera and microphone permission.")
            }
            if freeBytes < minimumFreeBytes {
                return RecordingTransition(phase: .failed("There is not enough free storage to start a recording. Free up space and try again."), message: "Low storage")
            }
            if thermalSerious {
                return RecordingTransition(phase: .failed("This device is too warm to start a reliable recording. Wait for it to cool down, then try again."), message: "Thermal pressure")
            }
            if countdown > 0 {
                return RecordingTransition(phase: .countdown(countdown))
            }
            return RecordingTransition(phase: .recording)
        case .countdownFinished:
            if case .countdown = phase { return RecordingTransition(phase: .recording) }
            return RecordingTransition(phase: phase)
        case .cancelCountdown:
            if case .countdown = phase { return RecordingTransition(phase: .idle, message: "Countdown cancelled.") }
            return RecordingTransition(phase: phase)
        case .stop:
            if phase == .recording { return RecordingTransition(phase: .stopping(partial: false)) }
            return RecordingTransition(phase: phase)
        case let .interrupted(message):
            if phase == .recording { return RecordingTransition(phase: .stopping(partial: true), finalizePartial: true, message: message) }
            return RecordingTransition(phase: phase, message: message)
        case .backgrounded:
            if phase == .recording {
                return RecordingTransition(phase: .stopping(partial: true), finalizePartial: true, message: "Recording stopped because Cuevora left the foreground. The take will be kept if it can be finished.")
            }
            if case .countdown = phase { return RecordingTransition(phase: .idle, message: "Countdown cancelled.") }
            return RecordingTransition(phase: phase)
        case let .fileReady(partial):
            if case .stopping = phase { return RecordingTransition(phase: .preview(partial: partial), allowCameraSwitch: true) }
            if case .recording = phase { return RecordingTransition(phase: .preview(partial: partial), allowCameraSwitch: true) }
            return RecordingTransition(phase: phase)
        case let .fileFailed(message):
            if case .stopping = phase {
                return RecordingTransition(phase: .failed("The recording could not be recovered. \(message)"), message: "Recovery failed")
            }
            if phase == .recording {
                return RecordingTransition(phase: .failed("The recording could not be recovered. \(message)"), message: "Recovery failed")
            }
            return RecordingTransition(phase: phase)
        case .discardPreview:
            if case .preview = phase {
                return RecordingTransition(phase: .idle, deleteFile: true, allowCameraSwitch: true, message: "Recording deleted.")
            }
            return RecordingTransition(phase: phase)
        case .shareFinished:
            if case .preview = phase { return RecordingTransition(phase: phase, allowCameraSwitch: true) }
            return RecordingTransition(phase: phase)
        case .shareCancelled:
            return keepAfterShare(phase: phase, message: "Sharing was cancelled. This recording is still on this device.")
        case .shareFailed:
            return keepAfterShare(phase: phase, message: "Sharing did not finish. This recording is still on this device.")
        case .photosSaved:
            return RecordingTransition(phase: phase, message: "Saved to Photos. The copy in Cuevora was kept.")
        case .photosDenied:
            return RecordingTransition(phase: phase, message: "Photos access is off, so nothing was added. The recording is still in Cuevora.")
        case .photosFailed:
            return RecordingTransition(phase: phase, message: "Photos could not save this video. The recording is still in Cuevora.")
        case .audioRouteChanged:
            if phase == .recording {
                return RecordingTransition(phase: .recording, message: "The audio route changed. Recording continues on the microphone that is available.")
            }
            return RecordingTransition(phase: phase)
        case .storageLow:
            if phase == .recording {
                return RecordingTransition(phase: .stopping(partial: true), finalizePartial: true, message: "Storage is too low to keep recording. Cuevora is saving the take.")
            }
            return RecordingTransition(phase: phase)
        case .switchCamera:
            let allowed = !isCapturing(phase) && !isStopping(phase)
            return RecordingTransition(
                phase: phase,
                allowCameraSwitch: allowed,
                message: allowed ? nil : "The camera can be switched between takes. Switching during a take is not used, because an uninterrupted recording has not been verified."
            )
        }
    }

    private static func keepAfterShare(phase: RecordingPhase, message: String) -> RecordingTransition {
        if case let .preview(partial) = phase {
            return RecordingTransition(phase: .preview(partial: partial), deleteFile: false, allowCameraSwitch: true, message: message)
        }
        return RecordingTransition(phase: phase, deleteFile: false, message: message)
    }

    private static func isCapturing(_ phase: RecordingPhase) -> Bool {
        if case .recording = phase { return true }
        if case .countdown = phase { return true }
        return false
    }

    private static func isStopping(_ phase: RecordingPhase) -> Bool {
        if case .stopping = phase { return true }
        return false
    }
}
