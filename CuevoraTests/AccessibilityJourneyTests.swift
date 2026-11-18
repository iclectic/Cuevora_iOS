import XCTest
@testable import CuevoraLogic

final class AccessibilityJourneyTests: XCTestCase {
    func testSystemSettingsAndProfilesStayUsableWithoutColourOrGestures() {
        let simple = AccessibilityPresentation.prompt(
            baseFont: 18,
            baseSpacing: 1.6,
            theme: .studio,
            gesturesEnabled: true,
            context: AccessibilityContext(profile: .simpleControls, reduceMotion: true, voiceOver: true)
        )
        XCTAssertTrue(simple.showSpeedControl)
        XCTAssertFalse(simple.showAppearanceControls)
        XCTAssertTrue(simple.showEstimates)
        XCTAssertFalse(simple.gesturesEnabled)
        XCTAssertFalse(simple.bounces)
        XCTAssertEqual(simple.fontSize, 32)

        let contrast = AccessibilityPresentation.prompt(
            baseFont: 32,
            baseSpacing: 1.6,
            theme: .studio,
            gesturesEnabled: true,
            context: AccessibilityContext(profile: .default, increaseContrast: true, differentiateWithoutColor: true, accessibilityTextSize: true)
        )
        XCTAssertEqual(contrast.theme, .highContrast)
        XCTAssertEqual(contrast.focusThickness, 4)
        XCTAssertEqual(contrast.fontSize, 44)
        XCTAssertTrue(contrast.selectionUsesShape)
        XCTAssertTrue(contrast.gesturesEnabled)

        let captions = AccessibilityPresentation.prompt(
            baseFont: 20,
            baseSpacing: 1.4,
            theme: .dark,
            gesturesEnabled: false,
            context: AccessibilityContext(profile: .captionFirst, boldText: true, switchControl: true)
        )
        XCTAssertTrue(captions.prominentEstimates)
        XCTAssertTrue(captions.boldText)
        XCTAssertFalse(captions.gesturesEnabled)
        XCTAssertEqual(captions.theme, .dark)

        let feedback = AccessibilityPresentation.playFeedback(playing: false, hapticsEnabled: false)
        XCTAssertFalse(feedback.haptics)
        XCTAssertEqual(feedback.visibleLabel, "Play")
        XCTAssertEqual(AccessibilityPresentation.touchSide(36), 44)
    }

    func testLayoutAppearanceAndEnglishStayExplicit() throws {
        XCTAssertEqual(ShellLayout.choose(regularWidth: true), .sidebar)
        XCTAssertEqual(ShellLayout.choose(regularWidth: false), .tabs)
        XCTAssertEqual(AppearanceChoice.resolve("light"), .light)
        XCTAssertEqual(AppearanceChoice.resolve("dark"), .dark)
        XCTAssertEqual(AppearanceChoice.resolve("system"), .system)
        XCTAssertEqual(AppearanceChoice.resolve("nope"), .system)
        XCTAssertEqual(AppLanguage.supported, ["en"])
        XCTAssertFalse(AppLanguage.includes("fr"))
        XCTAssertTrue(AppLanguage.interfaceNotice.contains("English"))
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Cuevora/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(catalog?["sourceLanguage"] as? String, AppLanguage.development)
        let strings = catalog?["strings"] as? [String: Any]
        XCTAssertEqual(strings?.keys.sorted(), [AppLanguage.interfaceNotice])
    }
}
