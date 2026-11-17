import SwiftData
import SwiftUI

struct RecordingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecordingItem.createdAt, order: .reverse) private var recordings: [RecordingItem]

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    ContentUnavailableView {
                        Label("No Recordings", systemImage: "video")
                    } description: {
                        Text("Takes you keep stay on this device. Start one from a script.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(recordings) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.scriptTitle).font(.body.weight(.semibold))
                                    Text(recordingLabel(item))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .swipeActions {
                                    Button("Delete", role: .destructive) { delete(item) }
                                }
                            }
                        } footer: {
                            Text("Recordings are files on this device. They are left out of script backups.")
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(CuevoraTheme.background)
            .navigationTitle("Recordings")
        }
    }

    private func recordingLabel(_ item: RecordingItem) -> String {
        let state = item.recoverable ? (item.partial ? "Partial take" : "Saved") : "Could not recover"
        return "\(state) · \(ReadTime.clock(item.duration)) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func delete(_ item: RecordingItem) {
        RecordingFiles.removeFile(named: item.fileName)
        context.delete(item)
        try? context.save()
    }
}
