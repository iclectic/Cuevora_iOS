import SwiftUI

struct ImportReview: View {
    @Environment(\.dismiss) private var dismiss
    var document: BackupDocumentModel
    var onMerge: () -> Void
    var onCopy: () -> Void
    var onReplace: () -> Void
    @State private var confirmReplace = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Scripts", value: "\(document.scripts.count)")
                    LabeledContent("From", value: sourceName)
                    Text("Recordings stay on this device. Nothing changes until you choose Merge, Add Copies, or Replace.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !document.notices.isEmpty {
                    Section("Notes") {
                        ForEach(document.notices, id: \.self) { Text($0) }
                    }
                }
                Section {
                    Button("Add Copies") { onCopy(); dismiss() }
                    Button("Replace Scripts", role: .destructive) { confirmReplace = true }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") { onMerge(); dismiss() }
                }
            }
            .confirmationDialog("Replace the scripts on this device?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace Scripts", role: .destructive) { onReplace(); dismiss() }
            } message: { Text("Scripts that are not in this file are removed, including their revision history. Saved recordings stay on this device.") }
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
