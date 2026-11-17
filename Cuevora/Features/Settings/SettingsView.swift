import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: AppPreferences
    @Query(sort: \RecordingItem.createdAt, order: .reverse) private var recordings: [RecordingItem]
    @Query private var scripts: [Script]
    @Query private var rehearsals: [RehearsalRecord]
    @State private var confirmClear = false
    @State private var shareURL: URL?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent(IdentityPolicy.statusTitle, value: "No account")
                    Text(IdentityPolicy.statusDetail)
                    Text(IdentityPolicy.deletionDetail)
                }
                Section("Appearance") {
                    Picker("Colour Mode", selection: $preferences.colorMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Picker("Reading Profile", selection: $preferences.accessibilityProfile) {
                        ForEach(ReadingProfile.allCases, id: \.rawValue) { profile in
                            Text(profile.title).tag(profile.rawValue)
                        }
                    }
                    Text(preferences.profile.detail).font(.footnote).foregroundStyle(.secondary)
                }
                Section("Teleprompter Defaults") {
                    Picker("Theme", selection: $preferences.defaultTheme) {
                        ForEach(PromptTheme.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    Stepper(value: $preferences.defaultSpeed, in: 1...10, step: 0.5) {
                        Text("Scroll speed \(preferences.defaultSpeed.formatted(.number.precision(.fractionLength(1))))")
                    }
                    Stepper(value: $preferences.defaultFontSize, in: 16...72, step: 2) { Text("Text size \(Int(preferences.defaultFontSize))") }
                    Stepper(value: $preferences.defaultLineSpacing, in: 1...3, step: 0.1) {
                        Text("Line spacing \(preferences.defaultLineSpacing.formatted(.number.precision(.fractionLength(1))))")
                    }
                    Stepper(value: $preferences.wordsPerMinute, in: 40...400, step: 5) { Text("Estimate \(preferences.wordsPerMinute) words per minute") }
                    Picker("Countdown", selection: $preferences.countdownDuration) {
                        Text("Off").tag(0); Text("3 seconds").tag(3); Text("5 seconds").tag(5); Text("10 seconds").tag(10)
                    }
                }
                Section("Recording and Controls") {
                    Toggle("Keep Screen Awake While Prompting", isOn: $preferences.keepScreenAwake)
                    Toggle("Mirror Text", isOn: $preferences.mirrorMode)
                    Toggle("Focus Guide", isOn: $preferences.focusLineEnabled)
                    Toggle("Haptics", isOn: $preferences.hapticsEnabled)
                    Toggle("Tap and Pinch Controls", isOn: $preferences.gestureControlsEnabled)
                    Toggle("Voice Commands", isOn: $preferences.voiceControlsEnabled)
                    Toggle("Adaptive Speed", isOn: $preferences.adaptiveScrollEnabled)
                    Picker("Recording Quality", selection: $preferences.recordingQuality) {
                        Text("Standard").tag("standard")
                        Text("High").tag("high")
                    }
                    Text("Voice commands and adaptive speed use on-device recognition only, and only when you turn them on. They stay off while a video is recording.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Recordings") {
                    if recordings.isEmpty { Text("Recordings stay on this device. None are saved yet.") }
                    ForEach(recordings) { item in
                        VStack(alignment: .leading) {
                            Text(item.scriptTitle)
                            Text(recordingLabel(item)).font(.caption).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                RecordingFiles.removeFile(named: item.fileName)
                                context.delete(item)
                                try? context.save()
                            }
                        }
                    }
                }
                Section("Privacy") {
                    Text("Scripts, settings, rehearsal reports and recordings stay on this device unless you export or share them. Cuevora does not collect analytics and does not require an account.")
                    Text(CloudSyncPolicy.explanation)
                    Button("Delete Local Data", role: .destructive) { confirmClear = true }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")
                    Link("Send Feedback", destination: URL(string: "mailto:ibimbraide@gmail.com")!)
                    Text("The interface is in English.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { try? context.save(); dismiss() } }
            .confirmationDialog("Delete all local Cuevora data?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete Local Data", role: .destructive) { clearLocalData() }
            } message: { Text("This removes scripts, revisions, rehearsal reports and recordings from this device. Export a backup first if you want a copy.") }
            .onDisappear { try? context.save() }
        }
    }

    private func recordingLabel(_ item: RecordingItem) -> String {
        let state = item.recoverable ? (item.partial ? "Partial take" : "Saved take") : "Recovery failed"
        return "\(state), \(ReadTime.clock(item.duration)), \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func clearLocalData() {
        for script in scripts { context.delete(script) }
        for record in rehearsals { context.delete(record) }
        for item in recordings {
            RecordingFiles.removeFile(named: item.fileName)
            context.delete(item)
        }
        preferences.apply(PortableSettings())
        preferences.onboardingComplete = true
        preferences.lastScriptUUID = nil
        preferences.lastProgress = 0
        try? context.save()
    }
}
