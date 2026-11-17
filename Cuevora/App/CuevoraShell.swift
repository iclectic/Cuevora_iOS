import SwiftData
import SwiftUI

enum CuevoraSection: Hashable {
    case scripts
    case recordings
    case settings
}

struct CuevoraShell: View {
    @Query private var preferencesList: [AppPreferences]
    @State private var section = CuevoraSection.scripts

    var body: some View {
        TabView(selection: $section) {
            LibraryView()
                .tabItem { Label("Scripts", systemImage: "text.quote") }
                .tag(CuevoraSection.scripts)
            RecordingsView()
                .tabItem { Label("Recordings", systemImage: "video") }
                .tag(CuevoraSection.recordings)
            settingsTab
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(CuevoraSection.settings)
        }
        .tint(CuevoraTheme.primary)
    }

    @ViewBuilder
    private var settingsTab: some View {
        if let preferences = preferencesList.first {
            SettingsView(preferences: preferences, embedded: true)
        } else {
            NavigationStack {
                ProgressView("Preparing Cuevora")
                    .navigationTitle("Settings")
            }
        }
    }
}
