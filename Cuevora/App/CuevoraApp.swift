import SwiftData
import SwiftUI

@main
struct CuevoraApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Script.self, RevisionSnapshot.self, AppPreferences.self, RecordingItem.self, RehearsalRecord.self])
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
        switch preferences.first?.colorMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private func ensurePreferences() {
        guard preferences.isEmpty else { return }
        context.insert(AppPreferences())
        try? context.save()
    }
}
