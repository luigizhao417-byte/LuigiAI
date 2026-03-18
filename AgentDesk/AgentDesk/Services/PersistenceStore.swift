import Foundation

struct AppSnapshot: Codable {
    var configuration: APIConfiguration
    var conversations: [ChatConversation]
    var tasks: [AgentTask]
    var selectedConversationID: UUID?
    var workspacePath: String?
    var learnedMemories: [LearnedMemoryItem]?
}

final class PersistenceStore {
    static let shared = PersistenceStore()

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let appSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let folderURL = appSupportURL.appendingPathComponent("AgentDesk", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        fileURL = folderURL.appendingPathComponent("AppState.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> AppSnapshot {
        guard let data = try? Data(contentsOf: fileURL) else {
            return AppSnapshot(
                configuration: APIConfiguration(),
                conversations: [],
                tasks: [],
                selectedConversationID: nil,
                workspacePath: nil,
                learnedMemories: nil
            )
        }

        do {
            return try decoder.decode(AppSnapshot.self, from: data)
        } catch {
            return AppSnapshot(
                configuration: APIConfiguration(),
                conversations: [],
                tasks: [],
                selectedConversationID: nil,
                workspacePath: nil,
                learnedMemories: nil
            )
        }
    }

    func save(_ snapshot: AppSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}
