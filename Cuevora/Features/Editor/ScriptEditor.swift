import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ScriptEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var script: Script
    var preferences: AppPreferences
    var embedded: Bool

    @State private var saveError = false
    @State private var tagText = ""
    @State private var lastSavedContent = ""
    @State private var saveStatus = "Saved"
    @State private var saveTask: Task<Void, Never>?
    @State private var revisionToRestore: RevisionSnapshot?
    @State private var importingText = false
    @State private var exportingText = false
    @State private var textDocument = TextDocument(text: "")
    @State private var importTextError = false
    @State private var pendingText: String?
    @State private var showPlayer = false
    @State private var showRecording = false
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $script.title)
                    .font(.title.bold())
                    .accessibilityLabel("Title")
                TextField("Tags", text: $tagText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Tags, separated by commas")
                Text(statisticsLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            TextEditor(text: $script.content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .accessibilityLabel("Script content")
        }
        .background(CuevoraTheme.background)
        .navigationTitle("Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !embedded {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveTask?.cancel()
                        if saveChanges() { dismiss() }
                    }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Text(saveStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Save status \(saveStatus)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Prompt", systemImage: "play.fill") { showPlayer = true }
                    .accessibilityLabel("Prompt")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Record", systemImage: "video") { showRecording = true }
                    Button("History", systemImage: "clock.arrow.circlepath") { showHistory = true }
                    Button("Import Text", systemImage: "square.and.arrow.down") { importingText = true }
                    Button("Export Text", systemImage: "square.and.arrow.up") {
                        textDocument = TextDocument(text: script.content)
                        exportingText = true
                    }
                    ShareLink(item: script.content, subject: Text(script.displayTitle)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(script: script, preferences: preferences, initialProgress: preferences.lastScriptUUID == script.identity ? preferences.lastProgress : 0)
        }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(script: script, preferences: preferences)
        }
        .sheet(isPresented: $showHistory) { historySheet }
        .alert("Unable to Save", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Your changes are still in the editor. Please try again.") }
        .confirmationDialog("Restore this revision?", isPresented: Binding(get: { revisionToRestore != nil }, set: { if !$0 { revisionToRestore = nil } }), titleVisibility: .visible) {
            Button("Restore") {
                if let revisionToRestore { script.content = revisionToRestore.content }
                revisionToRestore = nil
            }
        } message: { Text("The current text is kept in history when the script is saved.") }
        .fileImporter(isPresented: $importingText, allowedContentTypes: [.plainText, .utf8PlainText]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= BackupCodec.maxContentLength, let text = String(data: try Data(contentsOf: url), encoding: .utf8) else { throw BackupCodecError.invalidContent("text") }
                pendingText = text
            } catch { importTextError = true }
        }
        .fileExporter(isPresented: $exportingText, document: textDocument, contentType: .plainText, defaultFilename: "script") { result in
            if case .failure = result { saveError = true }
        }
        .alert("Unable to Import Text", isPresented: $importTextError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Choose a UTF-8 text file of 2 MB or less. The current script was not changed.") }
        .confirmationDialog("Replace script text?", isPresented: Binding(get: { pendingText != nil }, set: { if !$0 { pendingText = nil } }), titleVisibility: .visible) {
            Button("Replace Text") { if let pendingText { script.content = pendingText }; pendingText = nil }
        } message: { Text("The current text is kept in history when the script is saved.") }
        .onAppear {
            tagText = script.tags.joined(separator: ", ")
            lastSavedContent = script.content
            ScriptTransfer.promoteLegacyRevisions(for: script, in: context)
        }
        .onChange(of: script.title) { scheduleSave() }
        .onChange(of: script.content) { scheduleSave() }
        .onChange(of: tagText) { scheduleSave() }
        .onChange(of: scenePhase) {
            if scenePhase != .active && saveStatus != "Saved" { saveTask?.cancel(); _ = saveChanges() }
        }
        .interactiveDismissDisabled()
    }

    private var statisticsLine: String {
        let words = ReadTime.wordCount(script.content)
        let wordLabel = words == 1 ? "1 word" : "\(words) words"
        let estimate = ReadTime.clock(Double(ReadTime.seconds(text: script.content, wordsPerMinute: preferences.wordsPerMinute)))
        return "\(wordLabel) · \(script.content.count) characters · about \(estimate)"
    }

    private var historySheet: some View {
        NavigationStack {
            Group {
                if orderedSnapshots.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock", description: Text("Earlier versions appear here after you change the script."))
                } else {
                    List(orderedSnapshots) { snapshot in
                        Button {
                            revisionToRestore = snapshot
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.body.weight(.semibold))
                                Text(snapshot.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { showHistory = false }
            }
        }
    }

    private var orderedSnapshots: [RevisionSnapshot] {
        script.snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    private func scheduleSave() {
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            _ = saveChanges()
        }
    }

    private func saveChanges() -> Bool {
        script.tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let previous = lastSavedContent
        if previous != script.content && !previous.isEmpty {
            let snapshot = RevisionSnapshot(content: previous, createdAt: .now)
            snapshot.script = script
            context.insert(snapshot)
            let extras = script.snapshots.sorted { $0.createdAt > $1.createdAt }.dropFirst(BackupCodec.maxRevisions)
            for extra in extras { context.delete(extra) }
        }
        script.updatedAt = .now
        do {
            try context.save()
            lastSavedContent = script.content
            saveStatus = "Saved"
            return true
        } catch {
            saveStatus = "Not saved"
            saveError = true
            return false
        }
    }
}

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw BackupCodecError.invalidContent("text") }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
