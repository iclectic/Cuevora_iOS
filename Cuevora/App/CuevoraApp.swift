import SwiftData
import SwiftUI

extension Notification.Name {
    static let cuevoraNewScript = Notification.Name("cuevoraNewScript")
}

@main
struct CuevoraApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Script.self, RevisionSnapshot.self, AppPreferences.self, RecordingItem.self, RehearsalRecord.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Script") {
                    NotificationCenter.default.post(name: .cuevoraNewScript, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var preferences: [AppPreferences]

    var body: some View {
        CuevoraShell()
            .tint(CuevoraTheme.primary)
            .preferredColorScheme(colorScheme)
            .onAppear(perform: ensurePreferences)
    }

    private var colorScheme: ColorScheme? {
        switch AppearanceChoice.resolve(preferences.first?.colorMode) {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    private func ensurePreferences() {
        guard preferences.isEmpty else { return }
        context.insert(AppPreferences())
        try? context.save()
    }
}
