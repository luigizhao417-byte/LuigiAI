import Foundation

enum AgentLogLevel: String {
    case info
    case success
    case warning
    case error
}

struct AgentLogEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: AgentLogLevel
    let title: String
    let detail: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: AgentLogLevel,
        title: String,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.title = title
        self.detail = detail
    }
}
