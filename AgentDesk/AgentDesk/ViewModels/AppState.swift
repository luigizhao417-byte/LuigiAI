import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var configuration: APIConfiguration
    @Published var conversations: [ChatConversation]
    @Published var tasks: [AgentTask]
    @Published var selectedConversationID: UUID?
    @Published var workspacePath: String?
    @Published var learnedMemories: [LearnedMemoryItem]
    @Published var agentLogs: [AgentLogEntry] = []
    @Published var agentLastSummary: String?
    @Published var isLoading = false
    @Published var isAgentRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let persistenceStore: PersistenceStore
    private let aiService: AIService
    private let workspaceService: WorkspaceService
    private let commandService: LocalCommandService
    private let projectValidator: ProjectValidator
    private lazy var agentAutomationService = AgentAutomationService(
        aiService: aiService,
        workspaceService: workspaceService,
        commandService: commandService,
        projectValidator: projectValidator
    )

    private var activeResponseTask: Task<Void, Never>?
    private var activeAgentTask: Task<Void, Never>?

    init(
        persistenceStore: PersistenceStore = .shared,
        aiService: AIService = AIService(),
        workspaceService: WorkspaceService = WorkspaceService(),
        commandService: LocalCommandService = LocalCommandService(),
        projectValidator: ProjectValidator = ProjectValidator()
    ) {
        self.persistenceStore = persistenceStore
        self.aiService = aiService
        self.workspaceService = workspaceService
        self.commandService = commandService
        self.projectValidator = projectValidator

        let snapshot = persistenceStore.load()
        configuration = snapshot.configuration
        conversations = snapshot.conversations.sorted(by: { $0.updatedAt > $1.updatedAt })
        tasks = snapshot.tasks.sorted(by: { $0.updatedAt > $1.updatedAt })
        selectedConversationID = snapshot.selectedConversationID
        workspacePath = snapshot.workspacePath
        learnedMemories = (snapshot.learnedMemories ?? []).sorted(by: { $0.updatedAt > $1.updatedAt })

        if workspacePath == nil, let defaultWorkspaceURL = try? workspaceService.createDesktopWorkspace() {
            workspacePath = defaultWorkspaceURL.path
        }

        if conversations.isEmpty {
            let conversation = ChatConversation()
            conversations = [conversation]
            selectedConversationID = conversation.id
            persistSafely()
        } else if selectedConversation == nil {
            selectedConversationID = conversations.first?.id
        }
    }

    deinit {
        activeResponseTask?.cancel()
        activeAgentTask?.cancel()
    }

    var selectedConversation: ChatConversation? {
        guard let selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == selectedConversationID }) else {
            return nil
        }

        return conversations[index]
    }

    var workspaceURL: URL? {
        guard let workspacePath else {
            return nil
        }
        return URL(fileURLWithPath: workspacePath, isDirectory: true)
    }

    var pendingTasks: [AgentTask] {
        tasks
            .filter { $0.status != .completed }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    var recentMemories: [LearnedMemoryItem] {
        learnedMemories
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .prefix(12)
            .map { $0 }
    }

    var completedTasks: [AgentTask] {
        tasks
            .filter { $0.status == .completed }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    var pendingTaskCount: Int {
        tasks.filter { $0.status != .completed }.count
    }

    @discardableResult
    func createConversationAndSelect(title: String = "新对话", sourceTaskID: UUID? = nil) -> UUID {
        let conversation = ChatConversation(title: title, sourceTaskID: sourceTaskID)
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        persistSafely()
        return conversation.id
    }

    func selectConversation(_ conversation: ChatConversation) {
        selectedConversationID = conversation.id
        persistSafely()
    }

    func deleteConversation(_ conversation: ChatConversation) {
        if isLoading, selectedConversationID == conversation.id {
            cancelStreaming()
        }

        conversations.removeAll { $0.id == conversation.id }

        for index in tasks.indices where tasks[index].linkedConversationID == conversation.id {
            tasks[index].linkedConversationID = nil
            tasks[index].updatedAt = Date()
        }

        if conversations.isEmpty {
            let replacement = ChatConversation()
            conversations = [replacement]
            selectedConversationID = replacement.id
        } else if selectedConversationID == conversation.id {
            selectedConversationID = conversations.first?.id
        }

        persistSafely()
    }

    func updateConfiguration(url: String, key: String, model: String) {
        configuration = APIConfiguration(
            apiURL: url.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: key.trimmingCharacters(in: .whitespacesAndNewlines),
            modelName: model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        statusMessage = "配置已保存"
        persistSafely(reportErrors: true)
    }

    func setWorkspace(_ url: URL) {
        workspacePath = url.standardizedFileURL.path
        statusMessage = "已连接工作区"
        persistSafely(reportErrors: true)
    }

    @discardableResult
    func createDesktopWorkspace(named name: String = "AgentWorkspace") -> Bool {
        do {
            let url = try workspaceService.createDesktopWorkspace(named: name)
            setWorkspace(url)
            statusMessage = "桌面工作区已准备好"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func openWorkspaceInFinder() {
        guard let workspaceURL else {
            errorMessage = "请先选择工作区。"
            return
        }

        NSWorkspace.shared.open(workspaceURL)
    }

    func dismissError() {
        errorMessage = nil
    }

    func clearStatus() {
        statusMessage = nil
    }

    func clearAgentLogs() {
        agentLogs.removeAll()
        agentLastSummary = nil
    }

    func removeMemory(_ memory: LearnedMemoryItem) {
        learnedMemories.removeAll { $0.id == memory.id }
        persistSafely()
    }

    func clearLearnedMemories() {
        learnedMemories.removeAll()
        persistSafely()
    }

    func clearLocalDataKeepingAPI() {
        activeResponseTask?.cancel()
        activeAgentTask?.cancel()

        isLoading = false
        isAgentRunning = false
        tasks.removeAll()
        agentLogs.removeAll()
        agentLastSummary = nil
        learnedMemories.removeAll()
        workspacePath = nil

        let conversation = ChatConversation()
        conversations = [conversation]
        selectedConversationID = conversation.id
        statusMessage = "本地数据已清空，API 配置已保留"
        persistSafely()
    }

    @discardableResult
    func sendMessage(_ draft: String) -> Bool {
        learnFromUserInput(draft, source: "user_message")
        return startAssistantRun(
            userInput: draft,
            preferredTitle: nil,
            sourceTaskID: nil,
            forceNewConversation: false
        )
    }

    func cancelStreaming() {
        statusMessage = "正在停止..."
        activeResponseTask?.cancel()
    }

    @discardableResult
    func addTask(title: String, detail: String) -> Bool {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDetail.isEmpty else {
            errorMessage = "任务内容不能为空。"
            return false
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? Self.condensedTitle(from: trimmedDetail, fallback: "新任务") : trimmedTitle

        let task = AgentTask(title: finalTitle, detail: trimmedDetail)
        tasks.insert(task, at: 0)
        statusMessage = "任务已创建"
        learnFromUserInput(trimmedDetail, source: "task")
        persistSafely()
        return true
    }

    func deleteTask(_ task: AgentTask) {
        if task.status == .running {
            cancelStreaming()
        }

        tasks.removeAll { $0.id == task.id }
        persistSafely()
    }

    func toggleTaskCompletion(_ task: AgentTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }

        tasks[index].status = tasks[index].status == .completed ? .pending : .completed
        tasks[index].updatedAt = Date()
        persistSafely()
    }

    @discardableResult
    func runTask(_ task: AgentTask) -> Bool {
        guard !isAgentRunning else {
            errorMessage = "智能体正在执行，请先等待完成或停止。"
            return false
        }

        guard !isLoading else {
            errorMessage = "当前有回复正在生成，请先等待完成或点击停止。"
            return false
        }

        let shouldUseFreshConversation: Bool
        if let currentConversation = selectedConversation {
            shouldUseFreshConversation = !currentConversation.messages.isEmpty && currentConversation.sourceTaskID != task.id
        } else {
            shouldUseFreshConversation = true
        }

        let prompt = """
        请把下面的内容当作一个待完成任务来执行。

        任务标题：
        \(task.title)

        任务内容：
        \(task.detail)

        输出要求：
        1. 直接开始完成，不要重复题目。
        2. 如果需要假设，请先明确假设再继续。
        3. 结尾追加一个“结果总结”小节。
        """

        return startAssistantRun(
            userInput: prompt,
            preferredTitle: task.title,
            sourceTaskID: task.id,
            forceNewConversation: shouldUseFreshConversation
        )
    }

    @discardableResult
    func runAgent(goal: String) -> Bool {
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedGoal.isEmpty else {
            errorMessage = "请输入要自动执行的目标。"
            return false
        }

        guard configuration.isComplete else {
            errorMessage = "请先在设置中填写 API URL、API Key 和模型名称。"
            return false
        }

        guard !isLoading else {
            errorMessage = "当前普通聊天还在生成，请先等待完成或停止。"
            return false
        }

        guard !isAgentRunning else {
            errorMessage = "智能体已经在执行中了。"
            return false
        }

        let targetWorkspaceURL: URL
        if let workspaceURL {
            targetWorkspaceURL = workspaceURL
        } else {
            guard createDesktopWorkspace() else {
                return false
            }
            guard let createdWorkspaceURL = workspaceURL else {
                errorMessage = "无法创建桌面工作区。"
                return false
            }
            targetWorkspaceURL = createdWorkspaceURL
        }

        agentLogs.removeAll()
        agentLastSummary = nil
        addAgentLog(level: .info, title: "任务目标", detail: trimmedGoal)
        addAgentLog(level: .info, title: "工作区", detail: targetWorkspaceURL.path)
        learnFromUserInput(trimmedGoal, source: "agent_goal", force: true)

        let currentConfiguration = configuration
        let automationService = agentAutomationService

        isAgentRunning = true
        statusMessage = "智能体正在执行..."
        persistSafely()

        activeAgentTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let result = try await automationService.run(
                    goal: trimmedGoal,
                    workspaceURL: targetWorkspaceURL,
                    configuration: currentConfiguration,
                    memoryContext: self.memoryPromptText
                ) { entry in
                    await MainActor.run {
                        self.agentLogs.append(entry)
                    }
                } onLearnedMemory: { memoryNote in
                    await MainActor.run {
                        self.storeMemory(memoryNote, source: "agent_remember")
                    }
                }

                await MainActor.run {
                    self.isAgentRunning = false
                    self.activeAgentTask = nil
                    self.agentLastSummary = result.message
                    self.statusMessage = "智能体任务完成"
                    self.persistSafely()
                    self.appendAgentRunToConversation(
                        goal: trimmedGoal,
                        summary: result.message,
                        workspacePath: targetWorkspaceURL.path,
                        validationResult: result.validationResult
                    )
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isAgentRunning = false
                    self.activeAgentTask = nil
                    self.statusMessage = "智能体已停止"
                    self.addAgentLog(level: .warning, title: "任务中断", detail: "本次自动化执行已被停止。")
                    self.persistSafely()
                }
            } catch {
                await MainActor.run {
                    self.isAgentRunning = false
                    self.activeAgentTask = nil
                    self.statusMessage = nil
                    self.errorMessage = error.localizedDescription
                    self.addAgentLog(level: .error, title: "执行失败", detail: error.localizedDescription)
                    self.persistSafely()
                }
            }
        }

        return true
    }

    func cancelAgentRun() {
        statusMessage = "正在停止智能体..."
        activeAgentTask?.cancel()
    }

    func conversationTitle(for id: UUID?) -> String? {
        guard let id else {
            return nil
        }

        return conversations.first(where: { $0.id == id })?.title
    }

    static func condensedTitle(from text: String, fallback: String = "新对话") -> String {
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !singleLine.isEmpty else {
            return fallback
        }

        return String(singleLine.prefix(22))
    }

    @discardableResult
    private func startAssistantRun(
        userInput: String,
        preferredTitle: String?,
        sourceTaskID: UUID?,
        forceNewConversation: Bool
    ) -> Bool {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedInput.isEmpty else {
            return false
        }

        guard !isAgentRunning else {
            errorMessage = "智能体正在执行，请先等待完成或停止。"
            return false
        }

        guard configuration.isComplete else {
            errorMessage = "请先打开设置，填写 API URL、API Key 和模型名称。"
            return false
        }

        let conversationID: UUID
        if forceNewConversation || selectedConversation == nil {
            conversationID = createConversationAndSelect(
                title: preferredTitle ?? Self.condensedTitle(from: trimmedInput),
                sourceTaskID: sourceTaskID
            )
        } else {
            conversationID = selectedConversation!.id
            prepareConversationIfNeeded(
                conversationID: conversationID,
                preferredTitle: preferredTitle,
                sourceTaskID: sourceTaskID,
                firstInput: trimmedInput
            )
        }

        let userMessage = ChatMessage(role: .user, content: trimmedInput)
        appendMessage(userMessage, to: conversationID)

        let assistantPlaceholder = ChatMessage(role: .assistant, content: "")
        appendMessage(assistantPlaceholder, to: conversationID)

        if let sourceTaskID {
            updateTask(
                id: sourceTaskID,
                status: .running,
                linkedConversationID: conversationID,
                lastError: nil
            )
        }

        let requestMessages = makeRequestMessages(for: conversationID, excluding: assistantPlaceholder.id)
        let currentConfiguration = configuration
        let currentAIService = aiService

        isLoading = true
        errorMessage = nil
        statusMessage = "正在生成回复..."
        persistSafely()

        activeResponseTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let finalText = try await currentAIService.streamChat(
                    configuration: currentConfiguration,
                    messages: requestMessages
                ) { chunk in
                    await MainActor.run {
                        self.appendAssistantDelta(chunk, conversationID: conversationID, messageID: assistantPlaceholder.id)
                    }
                }

                await MainActor.run {
                    self.isLoading = false
                    self.activeResponseTask = nil
                    self.statusMessage = "回复完成"
                    self.touchConversation(conversationID)

                    if finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.replaceMessageContentIfNeeded(
                            conversationID: conversationID,
                            messageID: assistantPlaceholder.id,
                            content: "模型返回了空内容。"
                        )
                    }

                    if let sourceTaskID {
                        self.updateTask(
                            id: sourceTaskID,
                            status: .completed,
                            linkedConversationID: conversationID,
                            lastError: nil
                        )
                    }

                    self.persistSafely()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isLoading = false
                    self.activeResponseTask = nil
                    self.statusMessage = "已停止生成"
                    self.removeMessageIfEmpty(conversationID: conversationID, messageID: assistantPlaceholder.id)

                    if let sourceTaskID {
                        self.updateTask(
                            id: sourceTaskID,
                            status: .pending,
                            linkedConversationID: conversationID,
                            lastError: "任务已取消"
                        )
                    }

                    self.persistSafely()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.activeResponseTask = nil
                    self.statusMessage = nil
                    self.errorMessage = error.localizedDescription
                    self.removeMessageIfEmpty(conversationID: conversationID, messageID: assistantPlaceholder.id)

                    if let sourceTaskID {
                        self.updateTask(
                            id: sourceTaskID,
                            status: .pending,
                            linkedConversationID: conversationID,
                            lastError: error.localizedDescription
                        )
                    }

                    self.persistSafely()
                }
            }
        }

        return true
    }

    private func prepareConversationIfNeeded(
        conversationID: UUID,
        preferredTitle: String?,
        sourceTaskID: UUID?,
        firstInput: String
    ) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        if conversations[index].messages.isEmpty {
            conversations[index].title = preferredTitle ?? Self.condensedTitle(from: firstInput)
        }

        if conversations[index].sourceTaskID == nil {
            conversations[index].sourceTaskID = sourceTaskID
        }

        conversations[index].updatedAt = Date()
        sortConversations()
    }

    private func appendMessage(_ message: ChatMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        conversations[index].messages.append(message)
        conversations[index].updatedAt = Date()
        sortConversations()
    }

    private func appendAssistantDelta(_ delta: String, conversationID: UUID, messageID: UUID) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        conversations[conversationIndex].messages[messageIndex].content.append(delta)
        conversations[conversationIndex].updatedAt = Date()
        sortConversations()
    }

    private func replaceMessageContentIfNeeded(conversationID: UUID, messageID: UUID, content: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        if conversations[conversationIndex].messages[messageIndex].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conversations[conversationIndex].messages[messageIndex].content = content
        }
    }

    private func removeMessageIfEmpty(conversationID: UUID, messageID: UUID) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        let content = conversations[conversationIndex].messages[messageIndex].content
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if content.isEmpty {
            conversations[conversationIndex].messages.remove(at: messageIndex)
        }
    }

    private func touchConversation(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        conversations[index].updatedAt = Date()
        sortConversations()
    }

    private func sortConversations() {
        conversations.sort(by: { $0.updatedAt > $1.updatedAt })
    }

    private func makeRequestMessages(for conversationID: UUID, excluding excludedMessageID: UUID) -> [APIChatMessage] {
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
            return []
        }

        var requestMessages: [APIChatMessage] = []
        if let memoryPromptText, !memoryPromptText.isEmpty {
            requestMessages.append(
                APIChatMessage(
                    role: "system",
                    content: "以下是从历史交互中学习到的用户长期偏好与约束，请尽量持续遵守：\n\(memoryPromptText)"
                )
            )
        }

        requestMessages += conversation.messages
            .filter { $0.id != excludedMessageID }
            .map {
                APIChatMessage(
                    role: $0.role.rawValue,
                    content: $0.content
                )
            }
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return requestMessages
    }

    private func updateTask(
        id: UUID,
        status: AgentTaskStatus,
        linkedConversationID: UUID?,
        lastError: String?
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            return
        }

        tasks[index].status = status
        tasks[index].linkedConversationID = linkedConversationID
        tasks[index].lastError = lastError
        tasks[index].updatedAt = Date()
        tasks.sort(by: { $0.updatedAt > $1.updatedAt })
    }

    private func addAgentLog(level: AgentLogLevel, title: String, detail: String) {
        agentLogs.append(
            AgentLogEntry(
                level: level,
                title: title,
                detail: detail
            )
        )
    }

    private func appendAgentRunToConversation(
        goal: String,
        summary: String,
        workspacePath: String,
        validationResult: LocalCommandResult?
    ) {
        let conversationID = createConversationAndSelect(
            title: Self.condensedTitle(from: goal, fallback: "Agent任务")
        )

        appendMessage(
            ChatMessage(
                role: .user,
                content: "Agent 目标：\(goal)\n工作区：\(workspacePath)"
            ),
            to: conversationID
        )

        var assistantText = "智能体执行完成。\n\n\(summary)"
        if let validationResult {
            assistantText += "\n\n自检退出码：\(validationResult.exitCode)\n"
            assistantText += Self.trimmedConversationLog(validationResult.combinedOutput)
        }

        appendMessage(
            ChatMessage(
                role: .assistant,
                content: assistantText
            ),
            to: conversationID
        )

        touchConversation(conversationID)
        persistSafely()
    }

    private static func trimmedConversationLog(_ text: String, maxCharacters: Int = 1800) -> String {
        guard text.count > maxCharacters else {
            return text
        }
        return String(text.prefix(maxCharacters)) + "\n... output truncated ..."
    }

    private var memoryPromptText: String? {
        guard !recentMemories.isEmpty else {
            return nil
        }

        return recentMemories.enumerated().map { index, memory in
            "\(index + 1). \(memory.content)"
        }.joined(separator: "\n")
    }

    private func learnFromUserInput(_ text: String, source: String, force: Bool = false) {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        let keywords = [
            "记住", "以后", "默认", "需要", "不要", "必须", "请用",
            "优先", "保留", "继续", "喜欢", "习惯", "风格", "桌面", "工作区"
        ]

        let shouldStore = force ||
            keywords.contains(where: { trimmed.contains($0) }) ||
            (trimmed.count <= 140 && source == "user_message")

        guard shouldStore else {
            return
        }

        storeMemory(String(trimmed.prefix(260)), source: source)
    }

    private func storeMemory(_ content: String, source: String) {
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return
        }

        if let index = learnedMemories.firstIndex(where: {
            normalizedMemoryText($0.content) == normalizedMemoryText(cleaned) ||
            normalizedMemoryText($0.content).contains(normalizedMemoryText(cleaned)) ||
            normalizedMemoryText(cleaned).contains(normalizedMemoryText($0.content))
        }) {
            learnedMemories[index].content = cleaned
            learnedMemories[index].source = source
            learnedMemories[index].updatedAt = Date()
        } else {
            learnedMemories.insert(
                LearnedMemoryItem(
                    content: cleaned,
                    source: source
                ),
                at: 0
            )
        }

        if learnedMemories.count > 30 {
            learnedMemories = Array(learnedMemories.prefix(30))
        }

        persistSafely()
    }

    private func normalizedMemoryText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
    }

    private func persistSafely(reportErrors: Bool = false) {
        do {
            try persistenceStore.save(
                AppSnapshot(
                    configuration: configuration,
                    conversations: conversations,
                    tasks: tasks,
                    selectedConversationID: selectedConversationID,
                    workspacePath: workspacePath,
                    learnedMemories: learnedMemories
                )
            )
        } catch {
            if reportErrors {
                errorMessage = "本地保存失败：\(error.localizedDescription)"
            }
        }
    }
}
