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

    var body: some View {
        Form {
            TextField("Title", text: $script.title)
            TextField("Tags, separated by commas", text: $tagText)
            Section("Script") {
                TextEditor(text: $script.content)
                    .frame(minHeight: 240)
                    .accessibilityLabel("Script content")
            }
            Section("Text Files") {
                Button("Import Text File") { importingText = true }
                Button("Export Text File") { textDocument = TextDocument(text: script.content); exportingText = true }
                ShareLink(item: script.content, subject: Text(script.displayTitle)) { Label("Share Text", systemImage: "square.and.arrow.up") }
            }
            Section("History") {
                if orderedSnapshots.isEmpty { Text("No revisions yet").foregroundStyle(.secondary) }
                ForEach(orderedSnapshots) { snapshot in
                    Button("Restore \(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))") { revisionToRestore = snapshot }
                }
            }
            Section("Statistics") {
                let words = ReadTime.wordCount(script.content)
                Text("\(words) words")
                Text("\(script.content.count) characters")
                Text("Estimated \(ReadTime.clock(Double(ReadTime.seconds(text: script.content, wordsPerMinute: preferences.wordsPerMinute)))) at \(preferences.wordsPerMinute) words per minute")
            }
        }
        .safeAreaInset(edge: .bottom) { Text(saveStatus).font(.caption).foregroundStyle(.secondary).padding(8).accessibilityLabel("Save status \(saveStatus)") }
        .navigationTitle("Edit Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") {
                saveTask?.cancel()
                if saveChanges() { if !embedded { dismiss() } }
            }
        }
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
