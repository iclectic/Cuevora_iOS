import AVKit
import SwiftData
import SwiftUI

struct RecordingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecordingItem.createdAt, order: .reverse) private var recordings: [RecordingItem]
    @State private var pendingDelete: RecordingItem?

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
                                NavigationLink {
                                    RecordingPlayback(item: item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.scriptTitle).font(.body.weight(.semibold))
                                        Text(recordingLabel(item))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) { pendingDelete = item }
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
            .confirmationDialog("Delete this take?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete Take", role: .destructive) {
                    if let pendingDelete { delete(pendingDelete) }
                    pendingDelete = nil
                }
            } message: {
                Text("The video file is removed from this device.")
            }
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

private struct RecordingPlayback: View {
    let item: RecordingItem
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let url = try? RecordingFiles.url(for: item), item.recoverable {
                VideoPlayer(player: player)
                    .onAppear {
                        if player == nil { player = AVPlayer(url: url) }
                    }
                    .onDisappear { player?.pause() }
                    .toolbar {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            } else {
                ContentUnavailableView("Take Unavailable", systemImage: "video.slash", description: Text("This take could not be opened."))
            }
        }
        .navigationTitle(item.scriptTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
