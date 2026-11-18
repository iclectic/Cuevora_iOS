import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    /// On iPad the shell already provides the sidebar, so the script list stays a single column.
    var showsSplit: Bool = true
    var newScriptToken: Int = 0

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]
    @Query private var preferencesList: [AppPreferences]
    @Query private var rehearsals: [RehearsalRecord]

    @State private var search = ""
    @State private var selectedID: PersistentIdentifier?
    @State private var editorID: PersistentIdentifier?
    @State private var playerScript: Script?
    @State private var recordingScript: Script?
    @State private var saveError = false
    @State private var scriptToDelete: Script?
    @State private var deleted: StoredScript?
    @State private var exporting = false
    @State private var importing = false
    @State private var importingText = false
    @State private var backupDocument = BackupFile(data: Data("{}".utf8))
    @State private var pending: PendingImport?
    @State private var importError: String?
    @State private var backupMessage: String?
    @State private var showOnboarding = false
    @State private var handledNewScriptToken = 0

    private var preferences: AppPreferences? { preferencesList.first }
    private var selectedScript: Script? { scripts.first { $0.persistentModelID == selectedID } }

    private var filtered: [Script] {
        let query = scripts.filter { script in
            let matchesSearch = search.isEmpty || script.title.localizedCaseInsensitiveContains(search) || script.content.localizedCaseInsensitiveContains(search) || script.tags.contains { $0.localizedCaseInsensitiveContains(search) }
            let matchesTag = preferences?.selectedTag == nil || script.tags.contains(preferences?.selectedTag ?? "")
            return matchesSearch && matchesTag
        }
        let sorted: [Script]
        switch preferences?.sortOrder ?? 0 {
        case 1: sorted = query.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
        case 2: sorted = query.sorted { $0.content.count > $1.content.count }
        case 3: sorted = query.sorted { $0.createdDate > $1.createdDate }
        default: sorted = query
        }
        return sorted.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
            return false
        }
    }

    private var libraryTags: [String] {
        Array(Set(scripts.flatMap(\.tags))).sorted()
    }

    private var indexToken: String {
        scripts.map { "\($0.identity.uuidString)-\($0.updatedAt.timeIntervalSince1970)-\($0.pinned)" }.joined(separator: "|")
    }

    var body: some View {
        Group {
            if showsSplit && sizeClass == .regular {
                NavigationSplitView {
                    scriptList
                } detail: {
                    detail
                }
            } else {
                NavigationStack {
                    scriptList
                        .navigationDestination(item: $editorID) { id in
                            editor(for: id)
                        }
                }
            }
        }
        .onAppear {
            context.autosaveEnabled = false
            backfillIdentities()
            handleShortcut()
            consumeNewScriptRequest()
            ScriptIndex.sync(scripts)
            if preferences?.onboardingComplete == false { showOnboarding = true }
        }
        .onChange(of: indexToken) { ScriptIndex.sync(scripts) }
        .onChange(of: newScriptToken) { consumeNewScriptRequest() }
        .onChange(of: scenePhase) { if scenePhase == .active { handleShortcut() } }
        .fullScreenCover(isPresented: $showOnboarding) { onboarding }
        .fullScreenCover(item: $playerScript) { script in
            if let preferences {
                PlayerView(script: script, preferences: preferences, initialProgress: script.readingProgress)
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
            ImportReview(
                document: pending.document,
                onMerge: { apply(pending.document, choice: .merge) },
                onCopy: { apply(pending.document, choice: .copy) },
                onReplace: { apply(pending.document, choice: .replace) }
            )
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

    private var scriptList: some View {
        VStack(spacing: 0) {
            if !libraryTags.isEmpty { tagChips }
            list
        }
        .navigationTitle("Scripts")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $search, prompt: "Search")
        .toolbar { toolbar }
        .scrollContentBackground(.hidden)
        .background(CuevoraTheme.background)
        .dropDestination(for: String.self) { items, _ in
            let text = items.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return false }
            createScript(.blank, title: "Dropped Text", content: text)
            return true
        }
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagChip("All", tag: nil)
                ForEach(libraryTags, id: \.self) { tag in
                    tagChip(tag, tag: tag)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func tagChip(_ title: String, tag: String?) -> some View {
        let selected = preferences?.selectedTag == tag
        return Button(title) {
            preferences?.selectedTag = tag
            try? context.save()
        }
        .buttonStyle(.bordered)
        .tint(selected ? CuevoraTheme.primary : .secondary)
        .frame(minHeight: AccessibilityPresentation.minimumTouch)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedScript, let preferences {
            ScriptEditor(script: selectedScript, preferences: preferences, embedded: true)
        } else {
            ContentUnavailableView {
                Label("No Script Selected", systemImage: "text.quote")
            } description: {
                Text("Choose a script, or start a new one.")
            } actions: {
                Button("New Script") { createScript() }
                    .buttonStyle(.borderedProminent)
            }
            .background(CuevoraTheme.background)
        }
    }

    @ViewBuilder
    private func editor(for id: PersistentIdentifier) -> some View {
        if let script = scripts.first(where: { $0.persistentModelID == id }), let preferences {
            ScriptEditor(script: script, preferences: preferences, embedded: false)
        }
    }

    private var list: some View {
        Group {
            if scripts.isEmpty {
                ContentUnavailableView {
                    Label("No Scripts", systemImage: "text.quote")
                } description: {
                    Text("Write something to read aloud. It stays on this device.")
                } actions: {
                    Button("New Script") { createScript() }
                        .buttonStyle(.borderedProminent)
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                List(selection: $selectedID) {
                    if let recent = scripts.first(where: { $0.uuid == preferences?.lastScriptUUID }) {
                        Section {
                            Button { openPlayer(recent) } label: {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Continue")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(CuevoraTheme.primary)
                                        Text(recent.displayTitle)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("Opens the prompter at the last position")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .frame(width: 52, height: 52)
                                        .background(CuevoraTheme.primary, in: Circle())
                                }
                                .padding(.vertical, 6)
                            }
                            .accessibilityHint("Opens the prompter at the last reading position.")
                        }
                    }
                    Section {
                        ForEach(filtered) { script in
                            scriptRow(script)
                                .tag(script.persistentModelID)
                                .swipeActions(edge: .leading) {
                                    Button(script.pinned ? "Unpin" : "Pin", systemImage: script.pinned ? "pin.slash" : "pin") { togglePin(script) }
                                        .tint(.orange)
                                    Button("Prompt", systemImage: "play.fill") { openPlayer(script) }
                                        .tint(CuevoraTheme.primary)
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) { scriptToDelete = script }
                                }
                                .contextMenu {
                                    Button("Prompt", systemImage: "play.fill") { openPlayer(script) }
                                    Button("Record", systemImage: "video") { recordingScript = script }
                                    Button(script.pinned ? "Unpin" : "Pin", systemImage: script.pinned ? "pin.slash" : "pin") { togglePin(script) }
                                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(script) }
                                    Button("Copy Text", systemImage: "doc.on.doc") { UIPasteboard.general.string = script.content }
                                    ShareLink(item: script.content, subject: Text(script.displayTitle)) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    Button("Delete", systemImage: "trash", role: .destructive) { scriptToDelete = script }
                                }
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
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    private func scriptRow(_ script: Script) -> some View {
        HStack(spacing: 12) {
            Button { openEditor(script) } label: {
                HStack(spacing: 12) {
                    ScriptMark(title: script.displayTitle)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(script.displayTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if script.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption)
                                    .foregroundStyle(CuevoraTheme.primary)
                                    .accessibilityLabel("Pinned")
                            }
                        }
                        if preferences?.compactList != true {
                            Text(scriptSubtitle(script))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !script.tags.isEmpty {
                                Text(script.tags.prefix(3).joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            Button { openPlayer(script) } label: {
                Image(systemName: "play.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(CuevoraTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(CuevoraTheme.primary.opacity(0.14), in: Circle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Prompt \(script.displayTitle)")
        }
    }

    private func scriptSubtitle(_ script: Script) -> String {
        let words = ReadTime.wordCount(script.content)
        let wordLabel = words == 1 ? "1 word" : "\(words) words"
        return "\(script.updatedAt.formatted(.relative(presentation: .named))) · \(wordLabel)"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Library", systemImage: "ellipsis.circle") {
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
            Menu("New Script", systemImage: "square.and.pencil") {
                ForEach(ScriptTemplate.allCases) { template in
                    Button(template.title) { createScript(template) }
                }
            }
            .accessibilityLabel("New Script")
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Image("CuevoraLogo")
                            .resizable()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cuevora")
                                .font(.largeTitle.bold())
                            Text("Read, rehearse and record. Your scripts stay on this iPhone or iPad.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 22) {
                            WelcomeFeature(systemImage: "text.quote", title: "Scripts", detail: "Write, search and keep a short history of each script.")
                            WelcomeFeature(systemImage: "play.circle", title: "Prompter", detail: "Scroll at a steady speed, with controls you can see and hear.")
                            WelcomeFeature(systemImage: "video", title: "Record", detail: "Film yourself while the script stays on screen, not in the video.")
                            WelcomeFeature(systemImage: "lock", title: "On this device", detail: "No account. Camera, microphone, speech and Photos are asked for only when you use them.")
                        }
                    }
                    .padding(24)
                }
                Button("Continue") {
                    preferences?.onboardingComplete = true
                    try? context.save()
                    showOnboarding = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(CuevoraTheme.background)
        }
    }

    private func createScript(_ template: ScriptTemplate = .blank, title: String? = nil, content: String? = nil) {
        let script = Script()
        script.title = title ?? template.scriptTitle
        script.content = content ?? template.content
        context.insert(script)
        do {
            try context.save()
            openEditor(script)
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
        let removedID = script.persistentModelID
        let next = currentLibrary().deleting(id: script.identity.uuidString)
        scriptToDelete = nil
        commit(next, settings: nil, rehearsals: [])
        if selectedID == removedID { selectedID = nil }
    }

    private func restore(_ snapshot: StoredScript) {
        var library = currentLibrary()
        library.deleted = snapshot
        commit(library.undoingDelete(), settings: nil, rehearsals: [])
    }

    private func openPlayer(_ script: Script) {
        preferences?.lastScriptUUID = script.identity
        preferences?.lastProgress = script.readingProgress
        try? context.save()
        playerScript = script
    }

    private func togglePin(_ script: Script) {
        script.pinned.toggle()
        try? context.save()
    }

    private func consumeNewScriptRequest() {
        guard newScriptToken > handledNewScriptToken else { return }
        handledNewScriptToken = newScriptToken
        createScript(.blank)
    }

    private func backfillIdentities() {
        var changed = false
        for script in scripts {
            if script.uuid == nil {
                script.uuid = UUID()
                changed = true
            }
            if script.externalID.isEmpty {
                script.externalID = script.identity.uuidString
                changed = true
            }
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

    private func currentLibrary() -> ScriptLibrary {
        ScriptLibrary(
            scripts: scripts.map { script in
                StoredScript(id: script.identity.uuidString, script: ScriptTransfer.portable(script), readingProgress: script.readingProgress, pinned: script.pinned)
            },
            deleted: deleted
        )
    }

    private func apply(_ document: BackupDocumentModel, choice: ImportChoice) {
        let next = currentLibrary().choosing(choice, document: document)
        guard choice != .cancelled else {
            pending = nil
            return
        }
        let settings = choice == .copy ? nil : document.settings
        let sessions = choice == .copy ? [] : document.rehearsals
        let message: String
        switch choice {
        case .merge: message = "Matching scripts were updated. Other scripts on this device were kept. Recordings were not changed."
        case .replace: message = "Backup replaced the scripts on this device. Recordings were kept."
        case .copy: message = "Scripts were imported as copies. Existing scripts were kept."
        case .cancelled: message = ""
        }
        if commit(next, settings: settings, rehearsals: sessions, message: message) {
            pending = nil
        }
    }

    @discardableResult
    private func commit(_ library: ScriptLibrary, settings: PortableSettings?, rehearsals sessions: [PortableRehearsal], message: String? = nil) -> Bool {
        let current = Array(scripts)
        let existing = Dictionary(uniqueKeysWithValues: current.map { ($0.identity.uuidString, $0) })
        let nextIDs = Set(library.scripts.map(\.id))
        for script in current where !nextIDs.contains(script.identity.uuidString) {
            context.delete(script)
        }
        for stored in library.scripts {
            if let script = existing[stored.id] {
                ScriptTransfer.apply(stored, to: script, in: context)
            } else {
                _ = ScriptTransfer.insert(stored, into: context)
            }
        }
        if let settings { preferences?.apply(settings) }
        for session in sessions {
            guard let data = try? JSONEncoder().encode(session.metrics), let metricsJSON = String(data: data, encoding: .utf8) else { continue }
            let transcript = (try? JSONEncoder().encode(session.transcript)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let record = RehearsalRecord(scriptTitle: session.scriptTitle, startedAt: session.startedAt, endedAt: session.endedAt, summary: "Imported rehearsal estimate", metricsJSON: metricsJSON, transcriptJSON: transcript, transcriptRetained: !session.transcript.isEmpty)
            context.insert(record)
        }
        do {
            try context.save()
            deleted = library.deleted
            if let message { backupMessage = message }
            return true
        } catch {
            context.rollback()
            saveError = true
            return false
        }
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
            openEditor(script)
        } catch {
            importError = "The text file could not be imported. Nothing was changed."
        }
    }

    private func openEditor(_ script: Script) {
        selectedID = script.persistentModelID
        editorID = script.persistentModelID
    }

    private func handleShortcut() {
        switch ShortcutInbox.consume() {
        case .createScript: createScript(.blank)
        case .openMostRecent:
            if let recent = scripts.first { openEditor(recent) }
        case nil: break
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
