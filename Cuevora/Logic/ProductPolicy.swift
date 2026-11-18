import Foundation

/// Identity and sync claims the interface is allowed to make.
/// The audited Android app keeps guest access, gates Firebase behind configuration,
/// and does not sync scripts. This iOS app does not ship that optional identity SDK.
public enum IdentityPolicy {
    public static let signInAvailable = false
    public static let accountRequired = false
    public static let syncsScripts = false
    public static let statusTitle = "Guest on this device"
    public static let statusDetail = "Optional sign-in is not available in this iOS release. Cuevora does not require an account, and scripts stay on this device."
    public static let deletionDetail = "Delete Local Data removes scripts, revisions, rehearsal reports and recordings from this device. There is no Cuevora account on iOS to delete."
}

public enum CloudSyncPolicy {
    public static let enabled = false
    public static let recordingsIncluded = false
    public static let consentRequiredBeforeEnable = true
    public static let explanation = "iCloud sync is not turned on. Scripts, settings and recordings stay on this device unless you export or share them. A future sync would be optional, free, limited to scripts and settings, and would ask before it starts. Recordings would stay local."
}

public enum ShortcutAction: String, Equatable, Codable, CaseIterable {
    case createScript
    case openMostRecent
}

public enum ShortcutPolicy {
    /// Shortcuts open the library or editor. They do not start the camera or microphone.
    public static let startsCamera = false
    public static let startsMicrophone = false
    public static let actions = ShortcutAction.allCases
}

public enum ReleaseClaims {
    public static let readyToUpload = false
    public static let collectsDiagnostics = false
    public static let diagnosticMayIncludeScriptText = false
    public static let thirdPartySDKs: [String] = []
    /// Used only to decide whether a recording can start or must stop. The byte count is not shown or sent.
    public static let diskSpaceReason = "E174.1"
    public static let bundleIdentifier = "app.cuevora.teleprompter.ios"
    public static let marketingVersion = "0.1.0"
    public static let buildNumber = "1"

    public static func diagnostic(domain: String, code: Int, scriptText: String) -> [String: String] {
        _ = scriptText
        guard !collectsDiagnostics else { return [:] }
        return ["domain": domain, "code": String(code)]
    }
}

public struct PromptSession: Equatable, Codable {
    public var scriptID: String
    public var progress: Double

    public init(scriptID: String, progress: Double) {
        self.scriptID = scriptID
        self.progress = min(1, max(0, progress))
    }
}
