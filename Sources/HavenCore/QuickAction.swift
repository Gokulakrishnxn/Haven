import Foundation

/// A saved prompt that can be rerun in one step with whatever context is current.
public struct QuickAction: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var prompt: String
    /// Agent to use, or nil for the user's default.
    public var agent: Agent?
    public var model: String?

    public init(id: UUID = UUID(), name: String, prompt: String, agent: Agent? = nil, model: String? = nil) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.agent = agent
        self.model = model
    }
}
