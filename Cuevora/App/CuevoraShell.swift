import SwiftData
import SwiftUI

enum CuevoraSection: Hashable {
    case scripts
    case recordings
    case settings
}

struct CuevoraShell: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var preferencesList: [AppPreferences]
    @State private var section = CuevoraSection.scripts

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List(selection: $section) {
                        Label("Scripts", systemImage: "text.quote").tag(CuevoraSection.scripts)
                        Label("Recordings", systemImage: "video").tag(CuevoraSection.recordings)
                        Label("Settings", systemImage: "gearshape").tag(CuevoraSection.settings)
                    }
                    .navigationTitle("Cuevora")
                    .listStyle(.sidebar)
                } detail: {
                    sectionDetail(showsScriptSplit: false)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
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
            }
        }
        .tint(CuevoraTheme.primary)
    }

    @ViewBuilder
    private func sectionDetail(showsScriptSplit: Bool) -> some View {
        switch section {
        case .scripts:
            LibraryView(showsSplit: showsScriptSplit)
        case .recordings:
            RecordingsView()
        case .settings:
            settingsTab
        }
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
