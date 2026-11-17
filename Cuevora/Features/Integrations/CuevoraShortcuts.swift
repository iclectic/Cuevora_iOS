import AppIntents

struct CreateScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Script"
    static var description = IntentDescription("Creates a script in Cuevora. This does not open the camera or microphone.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        ShortcutInbox.write(.createScript)
        return .result()
    }
}

struct OpenRecentScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Most Recent Script"
    static var description = IntentDescription("Opens the most recently updated script. This does not open the camera or microphone.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        ShortcutInbox.write(.openMostRecent)
        return .result()
    }
}

struct CuevoraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CreateScriptIntent(), phrases: ["Create a script in \(.applicationName)"], shortTitle: "Create Script", systemImageName: "square.and.pencil")
        AppShortcut(intent: OpenRecentScriptIntent(), phrases: ["Open the latest script in \(.applicationName)"], shortTitle: "Open Latest Script", systemImageName: "doc.text")
    }
}
