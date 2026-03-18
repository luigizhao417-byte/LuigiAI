import Foundation

struct APIConfiguration: Codable, Equatable {
    var apiURL: String
    var apiKey: String
    var modelName: String

    init(
        apiURL: String = "",
        apiKey: String = "",
        modelName: String = "gpt-4o-mini"
    ) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.modelName = modelName
    }

    var isComplete: Bool {
        !apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
