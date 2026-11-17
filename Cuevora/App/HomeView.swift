import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @State private var search = ""
    @State private var selectedScript: Script?
    @State private var playerScript: Script?
    @State private var saveError = false
    @State private var scriptToDelete: Script?
    @State private var deleted: ScriptBackup?
    @State private var exporting = false
    @State private var importing = false
    @State private var document = BackupDocument()
    @State private var pendingImport: [ScriptBackup]?
    @State private var importError: String?
    @State private var sortOrder = 0
    @State private var selectedTag: String?
    @State private var compact = false
    @State private var backupMessage: String?

    private var filtered: [Script] {
        let matches = search.isEmpty ? scripts : scripts.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.content.localizedCaseInsensitiveContains(search) || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) }
        }
        let tagged = matches.filter { selectedTag == nil || $0.tags.contains(selectedTag!) }
        switch sortOrder {
        case 1: return tagged.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case 2: return tagged.sorted { $0.content.count > $1.content.count }
        default: return tagged
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if scripts.isEmpty {
                    ContentUnavailableView("No Scripts Yet", systemImage: "doc.text", description: Text("Create a script to get started."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    List {
                      ForEach(filtered) { script in
                        Button { selectedScript = script } label: {
                            VStack(alignment: .leading) {
                                Text(script.title.isEmpty ? "Untitled Script" : script.title).font(.headline)
                                if !compact { Text(script.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary) }
                                if !compact && !script.tags.isEmpty {
                                    Text(script.tags.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { scriptToDelete = script }
                        }
                        .contextMenu {
                            Button("Prompt", systemImage: "play.fill") { playerScript = script }
                            Button("Duplicate", systemImage: "doc.on.doc") {
                                let copy = Script()
                                ScriptBackup(script).apply(to: copy)
                                copy.title = "\(script.title) Copy"
                                copy.updatedAt = .now
                                context.insert(copy)
                                do { try context.save() } catch { context.rollback(); saveError = true }
                            }
                        }
                      }
                    }
                }
            }
            .navigationTitle("Cuevora")
            .onAppear { context.autosaveEnabled = false }
            .searchable(text: $search, prompt: "Search scripts")
            .safeAreaInset(edge: .top) {
                if let selectedTag {
                    HStack {
                        Text("Tag: \(selectedTag)")
                        Spacer()
                        Button("Clear") { self.selectedTag = nil }
                    }.font(.subheadline).padding(.horizontal).padding(.vertical, 8).background(.regularMaterial)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let deleted {
                    HStack {
                        Text("Script deleted")
                        Spacer()
                        Button("Undo") {
                            let restored = Script()
                            deleted.apply(to: restored)
                            context.insert(restored)
                            do { try context.save(); self.deleted = nil }
                            catch { context.rollback(); saveError = true }
                        }
                    }.padding().background(.regularMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Backup", systemImage: "ellipsis.circle") {
                        Picker("Sort", selection: $sortOrder) {
                            Text("Recently updated").tag(0)
                            Text("Title").tag(1)
                            Text("Longest").tag(2)
                        }
                        Toggle("Compact List", isOn: $compact)
                        Menu("Filter by Tag") {
                            Button("All Tags") { selectedTag = nil }
                            ForEach(Array(Set(scripts.flatMap(\.tags))).sorted(), id: \.self) { tag in
                                Button(tag) { selectedTag = tag }
                            }
                        }
                        if let recent = scripts.first {
                            Button("Open Most Recent") { selectedScript = recent }
                        }
                        Button("Export Backup") { document = BackupDocument(scripts: scripts.map(ScriptBackup.init)); exporting = true }
                        Button("Import Backup") { importing = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("New Script", systemImage: "plus") {
                    let script = Script()
                    context.insert(script)
                    do { try context.save(); selectedScript = script }
                    catch { context.delete(script); saveError = true }
                } }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "cuevora-backup") { result in
                switch result {
                case .success: backupMessage = "Backup exported. Recordings are not included."
                case .failure: saveError = true
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    guard let size, size <= 10_000_000 else { throw BackupError.invalid }
                    let data = try Data(contentsOf: url)
                    let backup = try JSONDecoder().decode(BackupDocument.Payload.self, from: data)
                    guard backup.version == 1, backup.scripts.count <= 10_000 else { throw BackupError.invalid }
                    guard backup.scripts.allSatisfy({ $0.revisions.count <= 10 && $0.title.count <= 10000 && $0.content.count <= 2_000_000 && $0.tags.count <= 1000 }) else { throw BackupError.invalid }
                    pendingImport = backup.scripts
                } catch { importError = "This file is not a supported Cuevora iOS backup, or it exceeds the import limits. Android backups are not yet supported." }
            }
            .confirmationDialog("Import backup?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                Button("Import Copies") {
                    for item in pendingImport ?? [] { let script = Script(); item.apply(to: script); context.insert(script) }
                    do { try context.save(); backupMessage = "Scripts imported as copies." } catch { context.rollback(); saveError = true }
                    pendingImport = nil
                }
            } message: { Text("This adds \(pendingImport?.count ?? 0) scripts as copies. Existing scripts stay unchanged.") }
            .alert("Cannot Import Backup", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: { Text(importError ?? "") }
            .alert("Backup", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
                Button("OK", role: .cancel) { backupMessage = nil }
            } message: { Text(backupMessage ?? "") }
            .sheet(item: $selectedScript) { ScriptEditor(script: $0) }
            .fullScreenCover(item: $playerScript) { PlayerView(script: $0) }
            .alert("Unable to Save Changes", isPresented: $saveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Please try again.") }
            .confirmationDialog("Delete this script?", isPresented: Binding(get: { scriptToDelete != nil }, set: { if !$0 { scriptToDelete = nil } }), titleVisibility: .visible) {
                Button("Delete Script", role: .destructive) {
                    if let script = scriptToDelete {
                        let snapshot = ScriptBackup(script)
                        context.delete(script)
                        do { try context.save(); deleted = snapshot } catch { context.rollback(); saveError = true }
                    }
                    scriptToDelete = nil
                }
            } message: { Text("This removes the script from this device.") }
        }
    }
}

private struct ScriptEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var script: Script
    @State private var saveError = false
    @State private var tagText = ""
    @State private var lastSavedContent = ""
    @State private var saveStatus = "Saved"
    @State private var saveTask: Task<Void, Never>?
    @State private var revisionToRestore: String?
    @State private var importingText = false
    @State private var exportingText = false
    @State private var textDocument = TextDocument(text: "")
    @State private var importTextError = false
    @State private var pendingText: String?

    var body: some View {
        NavigationStack {
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
                    ShareLink(item: script.content, subject: Text(script.title)) { Label("Share Text", systemImage: "square.and.arrow.up") }
                }
                Section("History") {
                    if script.revisions.isEmpty { Text("No revisions yet").foregroundStyle(.secondary) }
                    ForEach(Array(script.revisions.enumerated()), id: \.offset) { index, revision in
                        Button("Restore revision \(index + 1)") { revisionToRestore = revision }
                    }
                }
                Section("Statistics") {
                    Text("\(script.content.split(whereSeparator: { $0.isWhitespace }).count) words")
                    Text("\(script.content.count) characters")
                    Text("About \(Int(ceil(Double(script.content.split(whereSeparator: { $0.isWhitespace }).count) / 140.0))) minutes at 140 words per minute")
                }
            }
            .safeAreaInset(edge: .bottom) { Text(saveStatus).font(.caption).foregroundStyle(.secondary).padding(8) }
            .navigationTitle("Edit Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    saveTask?.cancel()
                    if saveChanges() { dismiss() }
                }
            }
            .alert("Unable to Save", isPresented: $saveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your changes could not be saved. Please try again.") }
            .confirmationDialog("Restore this revision?", isPresented: Binding(get: { revisionToRestore != nil }, set: { if !$0 { revisionToRestore = nil } }), titleVisibility: .visible) {
                Button("Restore") { if let revisionToRestore { script.content = revisionToRestore }; revisionToRestore = nil }
            } message: { Text("The current text will be kept in history when saved.") }
            .fileImporter(isPresented: $importingText, allowedContentTypes: [.plainText]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2_000_000,
                          let text = String(data: try Data(contentsOf: url), encoding: .utf8) else { throw BackupError.invalid }
                    pendingText = text
                } catch { importTextError = true }
            }
            .fileExporter(isPresented: $exportingText, document: textDocument, contentType: .plainText, defaultFilename: "script") { result in
                if case .failure = result { saveError = true }
            }
            .alert("Unable to Import Text", isPresented: $importTextError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Choose a UTF-8 text file smaller than 2 MB.") }
            .confirmationDialog("Replace script text?", isPresented: Binding(get: { pendingText != nil }, set: { if !$0 { pendingText = nil } }), titleVisibility: .visible) {
                Button("Replace Text") { if let pendingText { script.content = pendingText }; pendingText = nil }
            } message: { Text("The current text will be kept in history when saved.") }
        }
        .onAppear { tagText = script.tags.joined(separator: ", "); lastSavedContent = script.content }
        .onChange(of: script.title) { scheduleSave() }
        .onChange(of: script.content) { scheduleSave() }
        .onChange(of: tagText) { scheduleSave() }
        .onChange(of: scenePhase) {
            if scenePhase != .active && saveStatus != "Saved" { saveTask?.cancel(); _ = saveChanges() }
        }
        .interactiveDismissDisabled()
    }
}


private extension ScriptEditor {
    func scheduleSave() {
        saveStatus = "Saving…"
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            _ = saveChanges()
        }
    }

    func saveChanges() -> Bool {
        let oldRevisions = script.revisions
        script.tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let previous = lastSavedContent
        if previous != script.content && !previous.isEmpty {
            script.revisions.insert(previous, at: 0)
            script.revisions = Array(script.revisions.prefix(10))
        }
        script.updatedAt = .now
        do { try context.save(); lastSavedContent = script.content; saveStatus = "Saved"; return true }
        catch { script.revisions = oldRevisions; saveStatus = "Error saving"; saveError = true; return false }
    }
}

private struct ScriptBackup: Codable {
    var title: String
    var content: String
    var tags: [String]
    var revisions: [String]
    var updatedAt: Date
    init(_ script: Script) {
        title = script.title; content = script.content; tags = script.tags
        revisions = script.revisions; updatedAt = script.updatedAt
    }
    func apply(to script: Script) {
        script.title = title; script.content = content; script.tags = tags
        script.revisions = Array(revisions.prefix(10)); script.updatedAt = updatedAt
    }
}
private enum BackupError: Error { case invalid }
private struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw BackupError.invalid }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
private struct BackupDocument: FileDocument {
    struct Payload: Codable { var version: Int = 1; var scripts: [ScriptBackup] }
    static var readableContentTypes: [UTType] { [.json] }
    var payload: Payload
    init(scripts: [ScriptBackup] = []) { payload = Payload(scripts: scripts) }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalid }
        payload = try JSONDecoder().decode(Payload.self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(payload))
    }
}
