import SwiftData
import SwiftUI

struct RehearsalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let script: Script
    var preferences: AppPreferences
    @StateObject private var speech = OnDeviceSpeech()
    @State private var startedAt: Date?
    @State private var metrics: RehearsalMetrics?
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Speech") {
                    Text(SpeechPrivacy.onDeviceNote)
                    Text(SpeechPrivacy.retentionNote)
                    if let message = speech.message, !speech.listening {
                        Text(message)
                    }
                    if speech.listening { Text(speech.lastTranscript.isEmpty ? "Listening…" : speech.lastTranscript) }
                    Button(speech.listening ? "Stop and Estimate" : "Start Rehearsal") { speech.listening ? finish() : begin() }
                        .disabled(saved)
                }
                if let metrics {
                    Section("Estimate") {
                        Text("These figures are estimates from the on-device transcript, not a score.")
                        Text("Duration \(ReadTime.clock(Double(metrics.durationSeconds)))")
                        Text(metrics.wordsPerMinute.map { "About \($0) words per minute" } ?? "Words per minute unavailable")
                        Text(metrics.scriptCoverage.map { "About \(Int(($0 * 100).rounded())) percent of the script length" } ?? "Script coverage unavailable")
                        Text("\(metrics.longPauseCount) long pauses")
                        Text("\(metrics.fillerWordCount) filler-word matches")
                        ForEach(metrics.unavailableMetrics, id: \.self) { Text("\($0) unavailable").foregroundStyle(.secondary) }
                        ForEach(metrics.suggestions, id: \.self) { Text($0) }
                    }
                    Section {
                        Button("Save Report on This Device") { save(metrics) }.disabled(saved)
                        Button("Discard Transcript", role: .destructive) { discard() }
                    }
                }
            }
            .navigationTitle("Rehearsal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { if !saved { speech.stop(); speech.resetTranscript() }; dismiss() } }
            .onDisappear { if !saved { speech.stop() } }
        }
    }

    private func begin() {
        metrics = nil
        saved = false
        speech.resetTranscript()
        startedAt = Date()
        speech.start()
    }

    private func finish() {
        speech.stop()
        let end = Date()
        metrics = RehearsalAnalysis.analyze(
            scriptContent: script.content,
            events: speech.events,
            startedAt: (startedAt ?? end).timeIntervalSince1970 * 1000,
            endedAt: end.timeIntervalSince1970 * 1000
        )
    }

    private func save(_ metrics: RehearsalMetrics) {
        let record = ScriptTransfer.rehearsalRecord(for: script, metrics: metrics, events: speech.events, startedAt: startedAt ?? Date(), endedAt: Date())
        record.script = script
        context.insert(record)
        try? context.save()
        saved = true
    }

    private func discard() {
        speech.resetTranscript()
        metrics = nil
        saved = false
    }
}
