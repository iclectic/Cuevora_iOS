import Foundation

public struct AccessibilityContext: Equatable {
    public var profile: ReadingProfile
    public var reduceMotion: Bool
    public var increaseContrast: Bool
    public var differentiateWithoutColor: Bool
    public var boldText: Bool
    public var accessibilityTextSize: Bool
    public var voiceOver: Bool
    public var switchControl: Bool

    public init(
        profile: ReadingProfile,
        reduceMotion: Bool = false,
        increaseContrast: Bool = false,
        differentiateWithoutColor: Bool = false,
        boldText: Bool = false,
        accessibilityTextSize: Bool = false,
        voiceOver: Bool = false,
        switchControl: Bool = false
    ) {
        self.profile = profile
        self.reduceMotion = reduceMotion
        self.increaseContrast = increaseContrast
        self.differentiateWithoutColor = differentiateWithoutColor
        self.boldText = boldText
        self.accessibilityTextSize = accessibilityTextSize
        self.voiceOver = voiceOver
        self.switchControl = switchControl
    }
}

public struct PromptPresentation: Equatable {
    public var fontSize: Double
    public var lineSpacing: Double
    public var theme: PromptTheme
    public var focusThickness: Double
    public var boldText: Bool
    public var reduceMotion: Bool
    public var showSpeedControl: Bool
    public var showAppearanceControls: Bool
    public var showEstimates: Bool
    public var prominentEstimates: Bool
    public var gesturesEnabled: Bool
    public var bounces: Bool
    public var selectionUsesShape: Bool

    public init(
        fontSize: Double,
        lineSpacing: Double,
        theme: PromptTheme,
        focusThickness: Double,
        boldText: Bool,
        reduceMotion: Bool,
        showSpeedControl: Bool,
        showAppearanceControls: Bool,
        showEstimates: Bool,
        prominentEstimates: Bool,
        gesturesEnabled: Bool,
        bounces: Bool,
        selectionUsesShape: Bool
    ) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.theme = theme
        self.focusThickness = focusThickness
        self.boldText = boldText
        self.reduceMotion = reduceMotion
        self.showSpeedControl = showSpeedControl
        self.showAppearanceControls = showAppearanceControls
        self.showEstimates = showEstimates
        self.prominentEstimates = prominentEstimates
        self.gesturesEnabled = gesturesEnabled
        self.bounces = bounces
        self.selectionUsesShape = selectionUsesShape
    }
}

public struct ControlFeedback: Equatable {
    public var haptics: Bool
    public var visibleLabel: String

    public init(haptics: Bool, visibleLabel: String) {
        self.haptics = haptics
        self.visibleLabel = visibleLabel
    }
}

public enum AppearanceChoice: Equatable {
    case system, light, dark

    public static func resolve(_ stored: String?) -> AppearanceChoice {
        switch stored {
        case "light": .light
        case "dark": .dark
        default: .system
        }
    }
}

public enum ShellLayout: Equatable {
    case tabs, sidebar

    public static func choose(regularWidth: Bool) -> ShellLayout {
        regularWidth ? .sidebar : .tabs
    }
}

public enum AppLanguage {
    public static let development = "en"
    public static let supported = ["en"]
    public static let interfaceNotice = "The interface is in English."

    public static func includes(_ code: String) -> Bool {
        supported.contains(code)
    }
}

public enum AccessibilityPresentation {
    public static let minimumTouch: Double = 44

    public static func prompt(
        baseFont: Double,
        baseSpacing: Double,
        theme: PromptTheme,
        gesturesEnabled: Bool,
        context: AccessibilityContext
    ) -> PromptPresentation {
        let strongContrast = context.increaseContrast || context.profile.prefersHighContrast
        let quieter = context.reduceMotion || context.profile.prefersReducedMotion
        let assistivePointer = context.voiceOver || context.switchControl
        return PromptPresentation(
            fontSize: PromptTypography.fontSize(base: baseFont, profile: context.profile, accessibilitySize: context.accessibilityTextSize),
            lineSpacing: PromptTypography.lineSpacing(base: baseSpacing, profile: context.profile),
            theme: strongContrast ? .highContrast : theme,
            focusThickness: strongContrast ? 4 : 2,
            boldText: context.boldText || context.profile == .lowVision || context.profile == .highContrast,
            reduceMotion: quieter,
            showSpeedControl: true,
            showAppearanceControls: !context.profile.simplifiesControls,
            showEstimates: true,
            prominentEstimates: context.profile == .captionFirst,
            gesturesEnabled: gesturesEnabled && !assistivePointer,
            bounces: !quieter,
            selectionUsesShape: context.differentiateWithoutColor || strongContrast
        )
    }

    public static func playFeedback(playing: Bool, hapticsEnabled: Bool) -> ControlFeedback {
        ControlFeedback(haptics: hapticsEnabled, visibleLabel: playing ? "Pause" : "Play")
    }

    public static func touchSide(_ requested: Double) -> Double {
        max(requested, minimumTouch)
    }
}
