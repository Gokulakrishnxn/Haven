import Foundation

/// The active tab of the frontmost browser.
public struct BrowserTab: Codable, Equatable, Sendable {
    public var title: String
    public var url: String

    public init(title: String, url: String) { self.title = title; self.url = url }
}

/// What the user was looking at when they invoked Haven.
public struct TaskContext: Sendable {
    public var appName: String?
    public var selectedText: String?
    public var tab: BrowserTab?
    /// Markdown brief built from Annotate-mode pins.
    public var brief: String?
    /// Absolute paths of files the user attached.
    public var files: [String]

    public init(appName: String? = nil, selectedText: String? = nil, tab: BrowserTab? = nil, brief: String? = nil, files: [String] = []) {
        self.appName = appName
        self.selectedText = selectedText
        self.tab = tab
        self.brief = brief
        self.files = files
    }

    public var isEmpty: Bool { appName == nil && selectedText == nil && tab == nil && brief == nil && files.isEmpty }
}
