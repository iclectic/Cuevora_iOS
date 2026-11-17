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
    @State private var newScriptToken = 0

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List(selection: sidebarSelection) {
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
                .onReceive(NotificationCenter.default.publisher(for: .cuevoraNewScript)) { _ in
                    section = .scripts
                    newScriptToken += 1
                }
            } else {
                TabView(selection: $section) {
                    LibraryView(newScriptToken: newScriptToken)
                        .tabItem { Label("Scripts", systemImage: "text.quote") }
                        .tag(CuevoraSection.scripts)
                    RecordingsView()
                        .tabItem { Label("Recordings", systemImage: "video") }
                        .tag(CuevoraSection.recordings)
                    settingsTab
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(CuevoraSection.settings)
                }
                .onReceive(NotificationCenter.default.publisher(for: .cuevoraNewScript)) { _ in
                    section = .scripts
                    newScriptToken += 1
                }
            }
        }
        .tint(CuevoraTheme.primary)
    }

    /// iOS only accepts an optional list selection. The tab bar keeps a value selected.
    private var sidebarSelection: Binding<CuevoraSection?> {
        Binding(
            get: { section },
            set: { if let newValue = $0 { section = newValue } }
        )
    }

    @ViewBuilder
    private func sectionDetail(showsScriptSplit: Bool) -> some View {
        switch section {
        case .scripts:
            LibraryView(showsSplit: showsScriptSplit, newScriptToken: newScriptToken)
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
