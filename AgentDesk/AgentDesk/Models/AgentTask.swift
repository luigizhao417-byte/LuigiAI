import Foundation

enum AgentTaskStatus: String, Codable, CaseIterable {
    case pending
    case running
    case completed

    var title: String {
        switch self {
        case .pending:
            return "待执行"
        case .running:
            return "执行中"
        case .completed:
            return "已完成"
        }
    }
}

struct AgentTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var detail: String
    var status: AgentTaskStatus
    var createdAt: Date
    var updatedAt: Date
    var linkedConversationID: UUID?
    var lastError: String?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        status: AgentTaskStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        linkedConversationID: UUID? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedConversationID = linkedConversationID
        self.lastError = lastError
    }
}
