import SwiftUI
import SwiftData

@Model
final class Script {
    var title: String
    var content: String
    var updatedAt: Date
    var tags: [String] = []
    var revisions: [String] = []

    init() {
        title = "Untitled Script"
        content = ""
        updatedAt = .now
    }
}

@main
struct CuevoraApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(CuevoraTheme.primary)
        }
        .modelContainer(for: Script.self)
    }
}
