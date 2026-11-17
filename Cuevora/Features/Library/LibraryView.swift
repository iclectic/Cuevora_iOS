import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @Query private var preferencesList: [AppPreferences]
    @Query private var rehearsals: [RehearsalRecord]

    @State private var search = ""
    @State private var selectedID: PersistentIdentifier?
    @State private var playerScript: Script?
    @State private var recordingScript: Script?
    @State private var saveError = false
    @State private var scriptToDelete: Script?
    @State private var deleted: PortableScript?
    @State private var exporting = false
    @State private var importing = false
    @State private var importingText = false
    @State private var backupDocument = BackupFile(data: Data("{}".utf8))
    @State private var pending: PendingImport?
    @State private var importError: String?
    @State private var backupMessage: String?
    @State private var showSettings = false
    @State private var showOnboarding = false

    private var preferences: AppPreferences? { preferencesList.first }
    private var selectedScript: Script? { scripts.first { $0.persistentModelID == selectedID } }

    private var filtered: [Script] {
        let query = scripts.filter { script in
            let matchesSearch = search.isEmpty || script.title.localizedCaseInsensitiveContains(search) || script.content.localizedCaseInsensitiveContains(search) || script.tags.contains { $0.localizedCaseInsensitiveContains(search) }
            let matchesTag = preferences?.selectedTag == nil || script.tags.contains(preferences?.selectedTag ?? "")
            return matchesSearch && matchesTag
        }
        switch preferences?.sortOrder ?? 0 {
        case 1: return query.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
        case 2: return query.sorted { $0.content.count > $1.content.count }
        case 3: return query.sorted { $0.createdDate > $1.createdDate }
        default: return query
        }
    }

    var body: some View {
        NavigationSplitView {
            list
                .navigationTitle("Cuevora")
                .searchable(text: $search, prompt: "Search scripts")
                .toolbar { toolbar }
        } detail: {
            if let selectedScript, let preferences {
                ScriptEditor(script: selectedScript, preferences: preferences, embedded: true)
            } else {
                ContentUnavailableView("Select a Script", systemImage: "doc.text", description: Text("Choose a script to edit it. You can prompt or record from the list."))
            }
        }
        .onAppear {
            context.autosaveEnabled = false
            backfillIdentities()
            handleShortcut()
            if preferences?.onboardingComplete == false { showOnboarding = true }
        }
        .onChange(of: scenePhase) { if scenePhase == .active { handleShortcut() } }
        .sheet(isPresented: $showSettings) {
            if let preferences { SettingsView(preferences: preferences) }
        }
        .sheet(isPresented: $showOnboarding) { onboarding }
        .fullScreenCover(item: $playerScript) { script in
            if let preferences {
                PlayerView(script: script, preferences: preferences, initialProgress: preferences.lastScriptUUID == script.identity ? preferences.lastProgress : 0)
            }
        }
        .fullScreenCover(item: $recordingScript) { script in
            if let preferences { RecordingView(script: script, preferences: preferences) }
        }
        .fileExporter(isPresented: $exporting, document: backupDocument, contentType: .json, defaultFilename: "cuevora-backup") { result in
            backupMessage = (try? result.get()) == nil ? nil : "Backup exported. Recordings are not included."
            if case .failure = result { saveError = true }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in importBackup(result) }
        .fileImporter(isPresented: $importingText, allowedContentTypes: [.plainText]) { result in importText(result) }
        .sheet(item: $pending) { pending in
            ImportReview(document: pending.document, onCopy: { apply(pending.document, replacing: false) }, onReplace: { apply(pending.document, replacing: true) })
        }
        .alert("Cannot Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
        .alert("Backup", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
            Button("OK", role: .cancel) { backupMessage = nil }
        } message: { Text(backupMessage ?? "") }
        .alert("Unable to Save Changes", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Nothing was lost from the last successful save. Please try again.") }
        .confirmationDialog("Delete this script?", isPresented: Binding(get: { scriptToDelete != nil }, set: { if !$0 { scriptToDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Script", role: .destructive) { deleteSelected() }
        } message: { Text("You can undo this until you leave the library. Recordings already saved are kept.") }
    }

    private var list: some View {
        Group {
            if scripts.isEmpty {
                ContentUnavailableView("No Scripts Yet", systemImage: "doc.text", description: Text("Create a script to get started. Everything stays on this device."))
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                List(selection: $selectedID) {
                    if let recent = scripts.first(where: { $0.uuid == preferences?.lastScriptUUID }) {
                        Button("Resume \(recent.displayTitle)") { openPlayer(recent) }
                            .accessibilityHint("Opens the prompter at the last reading position.")
                    }
                    ForEach(filtered) { script in
                        Button { selectedID = script.persistentModelID } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(script.displayTitle).font(.headline)
                                if preferences?.compactList != true {
                                    Text(script.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                    if !script.tags.isEmpty { Text(script.tags.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .tag(script.persistentModelID)
                        .swipeActions { Button("Delete", role: .destructive) { scriptToDelete = script } }
                        .contextMenu {
                            Button("Prompt", systemImage: "play.fill") { openPlayer(script) }
                            Button("Record", systemImage: "video") { recordingScript = script }
                            Button("Duplicate", systemImage: "doc.on.doc") { duplicate(script) }
                            Button("Delete", systemImage: "trash", role: .destructive) { scriptToDelete = script }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let deleted {
                HStack {
                    Text("Script deleted")
                    Spacer()
                    Button("Undo") { restore(deleted) }
                }
                .padding()
                .background(.regularMaterial)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu("Library", systemImage: "line.3.horizontal.decrease.circle") {
                Picker("Sort", selection: sortBinding) {
                    Text("Recently updated").tag(0)
                    Text("Title").tag(1)
                    Text("Longest").tag(2)
                    Text("Recently created").tag(3)
                }
                Toggle("Compact List", isOn: compactBinding)
                Menu("Filter by Tag") {
                    Button("All Tags") { preferences?.selectedTag = nil }
                    ForEach(Array(Set(scripts.flatMap(\.tags))).sorted(), id: \.self) { tag in
                        Button(tag) { preferences?.selectedTag = tag }
                    }
                }
                Button("Import Text") { importingText = true }
                Button("Export Backup") { exportBackup() }
                Button("Import Backup") { importing = true }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape") { showSettings = true }.accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("New Script", systemImage: "plus") { createScript() }.accessibilityLabel("New Script")
        }
    }

    private var sortBinding: Binding<Int> {
        Binding(get: { preferences?.sortOrder ?? 0 }, set: { preferences?.sortOrder = $0; try? context.save() })
    }
    private var compactBinding: Binding<Bool> {
        Binding(get: { preferences?.compactList ?? false }, set: { preferences?.compactList = $0; try? context.save() })
    }

    private var onboarding: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image("CuevoraLogo").resizable().frame(width: 72, height: 72).accessibilityHidden(true)
                Text("Cuevora keeps scripts on this device.").font(.title2.bold())
                Text("There is no account and no sync. You can export a backup whenever you want. Camera, microphone, speech and Photos access are requested only for the feature you start.")
                Text(CloudSyncPolicy.explanation).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("Continue") {
                    preferences?.onboardingComplete = true
                    try? context.save()
                    showOnboarding = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }

    private func createScript() {
        let script = Script()
        context.insert(script)
        do {
            try context.save()
            selectedID = script.persistentModelID
        } catch {
            context.delete(script)
            saveError = true
        }
    }

    private func duplicate(_ script: Script) {
        var copy = ScriptTransfer.portable(script)
        copy.title = "\(script.displayTitle) Copy"
        copy.sourceID = nil
        let created = ScriptTransfer.insert(copy, into: context)
        created.updatedAt = .now
        do { try context.save() } catch { context.rollback(); saveError = true }
    }

    private func deleteSelected() {
        guard let script = scriptToDelete else { return }
        let snapshot = ScriptTransfer.portable(script)
        context.delete(script)
        do {
            try context.save()
            deleted = snapshot
            if selectedID == script.persistentModelID { selectedID = nil }
        } catch {
            context.rollback()
            saveError = true
        }
        scriptToDelete = nil
    }

    private func restore(_ snapshot: PortableScript) {
        _ = ScriptTransfer.insert(snapshot, into: context)
        do { try context.save(); deleted = nil } catch { context.rollback(); saveError = true }
    }

    private func openPlayer(_ script: Script) {
        let identity = script.identity
        if preferences?.lastScriptUUID != identity {
            preferences?.lastProgress = 0
        }
        preferences?.lastScriptUUID = identity
        try? context.save()
        playerScript = script
    }

    private func backfillIdentities() {
        var changed = false
        for script in scripts where script.uuid == nil {
            script.uuid = UUID()
            changed = true
        }
        if changed { try? context.save() }
    }

    private func exportBackup() {
        guard let preferences else { return }
        let sessions = rehearsals.compactMap(ScriptTransfer.portableRehearsal)
        do {
            let data = try BackupCodec.encode(scripts: scripts.map(ScriptTransfer.portable), settings: preferences.portable(), rehearsals: sessions)
            backupDocument = BackupFile(data: data)
            exporting = true
        } catch {
            saveError = true
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pending = PendingImport(document: try BackupCodec.decode(data))
        } catch let error as BackupCodecError {
            importError = backupMessage(for: error)
        } catch {
            importError = "This file could not be read. Nothing was changed."
        }
    }

    private func backupMessage(for error: BackupCodecError) -> String {
        switch error {
        case .malformed: "This file is not a Cuevora backup. Nothing was changed."
        case .unsupportedVersion: "This backup version is not supported. Nothing was changed."
        case .tooLarge: "This backup is larger than 10 MB. Nothing was changed."
        case .invalidContent(let detail): "\(detail) Nothing was changed."
        }
    }

    private func apply(_ document: BackupDocumentModel, replacing: Bool) {
        if replacing { scripts.forEach(context.delete) }
        for script in document.scripts { _ = ScriptTransfer.insert(script, into: context) }
        if let settings = document.settings { preferences?.apply(settings) }
        for session in document.rehearsals {
            guard let data = try? JSONEncoder().encode(session.metrics), let metricsJSON = String(data: data, encoding: .utf8) else { continue }
            let transcript = (try? JSONEncoder().encode(session.transcript)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let record = RehearsalRecord(scriptTitle: session.scriptTitle, startedAt: session.startedAt, endedAt: session.endedAt, summary: "Imported rehearsal estimate", metricsJSON: metricsJSON, transcriptJSON: transcript, transcriptRetained: !session.transcript.isEmpty)
            context.insert(record)
        }
        do {
            try context.save()
            backupMessage = replacing ? "Backup replaced the scripts on this device. Recordings were kept." : "Scripts were imported as copies. Existing scripts were kept."
        } catch {
            context.rollback()
            saveError = true
        }
        pending = nil
    }

    private func importText(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= BackupCodec.maxContentLength, let text = String(data: try Data(contentsOf: url), encoding: .utf8) else {
                throw BackupCodecError.invalidContent("Choose a UTF-8 text file of 2 MB or less.")
            }
            let script = Script()
            script.title = url.deletingPathExtension().lastPathComponent
            script.content = text
            context.insert(script)
            try context.save()
            selectedID = script.persistentModelID
        } catch {
            importError = "The text file could not be imported. Nothing was changed."
        }
    }

    private func handleShortcut() {
        switch ShortcutInbox.consume() {
        case .createScript: createScript()
        case .openMostRecent: selectedID = scripts.first?.persistentModelID
        case nil: break
        }
    }
}

private struct ImportReview: View {
    @Environment(\.dismiss) private var dismiss
    var document: BackupDocumentModel
    var onCopy: () -> Void
    var onReplace: () -> Void
    @State private var confirmReplace = false

    var body: some View {
        NavigationStack {
            List {
                Section("What will be imported") {
                    Text("\(document.scripts.count) scripts from \(sourceName).")
                    Text("Recordings are not in this file and will not be changed.")
                    ForEach(document.notices, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Import Backup")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Button("Import as Copies") { onCopy(); dismiss() }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity, minHeight: 44)
                    Button("Replace Scripts", role: .destructive) { confirmReplace = true }.frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding()
            }
            .confirmationDialog("Replace the scripts on this device?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace Scripts", role: .destructive) { onReplace(); dismiss() }
            } message: { Text("Existing scripts and their revision history are removed. Saved recordings stay on this device.") }
        }
    }

    private var sourceName: String {
        switch document.source {
        case .androidVersion1: "an Android Cuevora backup"
        case .iosVersion1: "an earlier iOS backup"
        case .iosVersion2: "a Cuevora iOS backup"
        }
    }
}

struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupCodecError.malformed }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PendingImport: Identifiable {
    let id = UUID()
    let document: BackupDocumentModel
}
