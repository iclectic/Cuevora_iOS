import SwiftUI

enum CuevoraTheme {
    static let primary = Color("Primary")
    static let background = Color("Background")
    /// Brand amber, HSL 38° / 93% / 50%, used for recording.
    static let amber = Color(red: 0.965, green: 0.717, blue: 0.035)
}

struct ScriptMark: View {
    var title: String

    private var letter: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "C").uppercased()
    }

    var body: some View {
        Text(letter)
            .font(.headline)
            .foregroundStyle(CuevoraTheme.primary)
            .frame(width: 44, height: 44)
            .background(CuevoraTheme.primary.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct WelcomeFeature: View {
    var systemImage: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(CuevoraTheme.primary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
