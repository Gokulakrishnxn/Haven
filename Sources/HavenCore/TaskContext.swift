import Foundation

/// What the user was looking at when they invoked Haven.
public struct TaskContext: Sendable {
    public var appName: String?
    public var selectedText: String?
    /// Markdown brief built from Annotate-mode pins.
    public var brief: String?

    public init(appName: String? = nil, selectedText: String? = nil, brief: String? = nil) {
        self.appName = appName
        self.selectedText = selectedText
        self.brief = brief
    }

    public var isEmpty: Bool { appName == nil && selectedText == nil && brief == nil }
}
