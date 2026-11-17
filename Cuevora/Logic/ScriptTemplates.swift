import Foundation

public enum ScriptTemplate: String, CaseIterable, Identifiable {
    case blank
    case introduction
    case lesson
    case announcement

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blank: "Blank"
        case .introduction: "Introduction"
        case .lesson: "Lesson"
        case .announcement: "Announcement"
        }
    }

    public var scriptTitle: String {
        switch self {
        case .blank: "Untitled Script"
        case .introduction: "Introduction"
        case .lesson: "Lesson"
        case .announcement: "Announcement"
        }
    }

    public var content: String {
        switch self {
        case .blank:
            ""
        case .introduction:
            """
            Hello, and welcome.

            Today I want to walk you through one idea, slowly and clearly.

            Here is the point I hope you remember.

            Thank you for listening.
            """
        case .lesson:
            """
            What we will cover

            First, the idea in one sentence.

            Then a short example.

            Finally, what to try on your own.
            """
        case .announcement:
            """
            Here is the news.

            What is changing.

            When it starts.

            Where to find the details.
            """
        }
    }
}
