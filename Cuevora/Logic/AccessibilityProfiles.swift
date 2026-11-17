import Foundation

public enum ReadingProfile: String, CaseIterable, Codable, Equatable {
    case `default`
    case dyslexia
    case lowVision = "low-vision"
    case highContrast = "high-contrast"
    case calmFocus = "calm-focus"
    case captionFirst = "caption-first"
    case simpleControls = "simple-controls"

    public var title: String {
        switch self {
        case .default: "Default"
        case .dyslexia: "Dyslexia-friendly"
        case .lowVision: "Low vision"
        case .highContrast: "High contrast"
        case .calmFocus: "Calm focus"
        case .captionFirst: "Caption-first"
        case .simpleControls: "Simple controls"
        }
    }

    public var detail: String {
        switch self {
        case .default: "Use your normal prompting settings."
        case .dyslexia: "Adds more spacing and a steadier line rhythm."
        case .lowVision: "Prioritises larger text and controls."
        case .highContrast: "Uses stronger contrast for text and controls."
        case .calmFocus: "Reduces motion and keeps the interface quieter."
        case .captionFirst: "Keeps the transcript and estimates visible."
        case .simpleControls: "Shows fewer controls while prompting."
        }
    }

    public var minimumFontSize: Double {
        switch self {
        case .default: 16
        case .dyslexia, .calmFocus, .captionFirst: 30
        case .lowVision: 44
        case .highContrast, .simpleControls: 32
        }
    }

    public var lineSpacingMultiplier: Double {
        switch self {
        case .default: 1
        case .dyslexia: 1.2
        case .lowVision: 1.25
        case .highContrast, .captionFirst, .simpleControls: 1.1
        case .calmFocus: 1.15
        }
    }

    public var prefersReducedMotion: Bool {
        self == .calmFocus || self == .simpleControls
    }

    public var simplifiesControls: Bool {
        self == .lowVision || self == .calmFocus || self == .simpleControls
    }

    public var prefersHighContrast: Bool {
        self == .lowVision || self == .highContrast
    }
}

public enum ReadingProfileStyle {
    public static func fontSize(_ fontSize: Double, profile: ReadingProfile) -> Double {
        max(fontSize, profile.minimumFontSize)
    }

    public static func lineSpacing(_ lineSpacing: Double, profile: ReadingProfile) -> Double {
        let spaced = max(lineSpacing, lineSpacing * profile.lineSpacingMultiplier)
        return (spaced * 100).rounded() / 100
    }
}

public struct PromptLine: Equatable {
    public var text: String
    public var highlighted: Bool
    public var sectionBreak: Bool

    public init(text: String, highlighted: Bool, sectionBreak: Bool) {
        self.text = text
        self.highlighted = highlighted
        self.sectionBreak = sectionBreak
    }
}

public enum PromptText {
    public static func lines(content: String, markers: [Int], highlights: [Int]) -> [PromptLine] {
        let source = content.isEmpty ? ["This script is empty."] : content.components(separatedBy: "\n")
        return source.enumerated().map { index, line in
            PromptLine(
                text: line.isEmpty ? " " : line,
                highlighted: highlights.contains(index),
                sectionBreak: markers.contains(index)
            )
        }
    }
}

public enum PromptTheme: String, CaseIterable, Codable, Equatable {
    case dark, light, studio, highContrast = "high-contrast"

    public var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .studio: "Studio"
        case .highContrast: "High Contrast"
        }
    }

    public var backgroundHex: String {
        switch self {
        case .dark: "#0A0A0A"
        case .light: "#FAFAFA"
        case .studio: "#1A1A2E"
        case .highContrast: "#000000"
        }
    }

    public var foregroundHex: String {
        switch self {
        case .dark: "#F0F0F0"
        case .light: "#1A1A1A"
        case .studio: "#00D4AA"
        case .highContrast: "#FFFFFF"
        }
    }
}
