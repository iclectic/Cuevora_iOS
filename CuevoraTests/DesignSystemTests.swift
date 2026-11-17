import XCTest
@testable import CuevoraLogic

final class DesignSystemTests: XCTestCase {
    func testReadingProfilesRaiseTheFloorWithoutLoweringALargerChoice() {
        XCTAssertEqual(ReadingProfileStyle.fontSize(18, profile: .lowVision), 44)
        XCTAssertEqual(ReadingProfileStyle.fontSize(60, profile: .lowVision), 60)
        XCTAssertEqual(ReadingProfileStyle.lineSpacing(1.6, profile: .dyslexia), 1.92)
        XCTAssertTrue(ReadingProfile.simpleControls.simplifiesControls)
        XCTAssertTrue(ReadingProfile.calmFocus.prefersReducedMotion)
        XCTAssertEqual(PromptTheme.allCases.count, 4)
        XCTAssertEqual(PromptTheme.studio.foregroundHex, "#00D4AA")
    }

    func testPromptLinesKeepMarkersAndHighlights() {
        let lines = PromptText.lines(content: "One\n\nThree", markers: [2], highlights: [0])
        XCTAssertEqual(lines.map(\.text), ["One", " ", "Three"])
        XCTAssertTrue(lines[0].highlighted)
        XCTAssertTrue(lines[2].sectionBreak)
        XCTAssertEqual(PromptText.lines(content: "", markers: [], highlights: []).first?.text, "This script is empty.")
    }

    func testScriptTemplatesOfferABlankPageAndThreeStartingPoints() {
        XCTAssertEqual(ScriptTemplate.allCases.map(\.title), ["Blank", "Introduction", "Lesson", "Announcement"])
        XCTAssertEqual(ScriptTemplate.blank.content, "")
        XCTAssertTrue(ScriptTemplate.lesson.content.contains("example"))
        XCTAssertEqual(ScriptTemplate.introduction.scriptTitle, "Introduction")
    }

    func testDocumentedBrandContrastClearsTheBodyTextThreshold() {
        let lightPrimary = contrast(foreground: (0.49866, 0.23140, 0.92860), background: (0.97, 0.97, 0.97))
        let darkPrimary = contrast(foreground: (0.64840, 0.53680, 0.98320), background: (0.04741, 0.04240, 0.11760))
        XCTAssertGreaterThan(lightPrimary, 4.5)
        XCTAssertGreaterThan(darkPrimary, 4.5)
    }

    private func contrast(foreground: (Double, Double, Double), background: (Double, Double, Double)) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: (Double, Double, Double)) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.0) + 0.7152 * channel(color.1) + 0.0722 * channel(color.2)
    }
}
