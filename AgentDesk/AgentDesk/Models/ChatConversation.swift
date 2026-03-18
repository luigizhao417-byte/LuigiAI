import Foundation

struct ChatConversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]
    var sourceTaskID: UUID?

    init(
        id: UUID = UUID(),
        title: String = "新对话",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = [],
        sourceTaskID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.sourceTaskID = sourceTaskID
    }

    var previewText: String {
        guard let lastMessage = messages.last else {
            return "还没有消息"
        }

        let condensed = lastMessage.content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if condensed.isEmpty {
            return "正在准备回复..."
        }

        return String(condensed.prefix(72))
    }
}
