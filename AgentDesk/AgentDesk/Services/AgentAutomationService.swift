import Foundation

struct AgentRunSummary {
    let message: String
    let wroteFiles: Bool
    let validationResult: LocalCommandResult?
}

enum AgentAutomationError: LocalizedError {
    case invalidPlan(String)
    case exhaustedIterations

    var errorDescription: String? {
        switch self {
        case let .invalidPlan(message):
            return "智能体计划格式无效：\(message)"
        case .exhaustedIterations:
            return "智能体达到最大执行轮次，任务可能尚未完全完成。"
        }
    }
}

struct AgentAutomationService {
    private let aiService: AIService
    private let workspaceService: WorkspaceService
    private let commandService: LocalCommandService
    private let projectValidator: ProjectValidator

    init(
        aiService: AIService = AIService(),
        workspaceService: WorkspaceService = WorkspaceService(),
        commandService: LocalCommandService = LocalCommandService(),
        projectValidator: ProjectValidator = ProjectValidator()
    ) {
        self.aiService = aiService
        self.workspaceService = workspaceService
        self.commandService = commandService
        self.projectValidator = projectValidator
    }

    func run(
        goal: String,
        workspaceURL: URL,
        configuration: APIConfiguration,
        memoryContext: String?,
        onLog: @escaping @Sendable (AgentLogEntry) async -> Void,
        onLearnedMemory: @escaping @Sendable (String) async -> Void
    ) async throws -> AgentRunSummary {
        let snapshot = try workspaceService.snapshot(in: workspaceURL, lineBudget: 5000, fileLimit: 40)
        await onLog(
            AgentLogEntry(
                level: .info,
                title: "已载入上下文",
                detail: "工作区共读取 \(snapshot.fileList.count) 个文件路径，代码上下文约 \(snapshot.includedLineCount) 行。"
            )
        )

        var messages = [APIChatMessage(role: "system", content: Self.systemPrompt)]
        if let memoryContext, !memoryContext.isEmpty {
            messages.append(
                APIChatMessage(
                    role: "system",
                    content: "以下是智能体从用户历史输入中学习到的长期偏好与约束，请尽量持续遵守：\n\(memoryContext)"
                )
            )
        }
        messages.append(APIChatMessage(role: "user", content: Self.initialPrompt(goal: goal, snapshot: snapshot)))

        var wroteFiles = false
        var finalSummary = "智能体任务已执行。"
        var reachedFinish = false

        for round in 1 ... 6 {
            let roundResult = try await executeRound(
                label: "第\(round)轮",
                workspaceURL: workspaceURL,
                configuration: configuration,
                messages: &messages,
                onLog: onLog,
                onLearnedMemory: onLearnedMemory
            )

            wroteFiles = wroteFiles || roundResult.wroteFiles

            if let finishReason = roundResult.finishReason {
                finalSummary = finishReason
                reachedFinish = true
                break
            }
        }

        var validationResult: LocalCommandResult?

        if wroteFiles, let validationCommand = projectValidator.suggestedCommand(in: workspaceURL) {
            validationResult = try await validate(
                using: validationCommand,
                workspaceURL: workspaceURL,
                onLog: onLog
            )

            if let currentValidationResult = validationResult, currentValidationResult.exitCode != 0 {
                for repairRound in 1 ... 2 {
                    messages.append(
                        APIChatMessage(
                            role: "user",
                            content: """
                            自动自检失败。请根据下面的错误继续修复当前工作区，然后返回下一轮 JSON 动作。
                            你可以继续 read_file / write_file / run_command。
                            只有当你认为可以再次检查时，才返回 finish。

                            \(currentValidationResult.combinedOutput)
                            """
                        )
                    )

                    let repairResult = try await executeRound(
                        label: "修复轮\(repairRound)",
                        workspaceURL: workspaceURL,
                        configuration: configuration,
                        messages: &messages,
                        onLog: onLog,
                        onLearnedMemory: onLearnedMemory
                    )

                    wroteFiles = wroteFiles || repairResult.wroteFiles

                    validationResult = try await validate(
                        using: validationCommand,
                        workspaceURL: workspaceURL,
                        onLog: onLog
                    )

                    if let finishReason = repairResult.finishReason {
                        finalSummary = finishReason
                    }

                    if validationResult?.exitCode == 0 {
                        reachedFinish = true
                        break
                    }
                }
            }
        } else if wroteFiles {
            await onLog(
                AgentLogEntry(
                    level: .warning,
                    title: "未发现自检命令",
                    detail: "当前工作区没有识别到 `.xcodeproj` 或 `Package.swift`，因此无法自动编译检查。"
                )
            )
        }

        if !reachedFinish && !wroteFiles {
            throw AgentAutomationError.exhaustedIterations
        }

        return AgentRunSummary(
            message: finalSummary,
            wroteFiles: wroteFiles,
            validationResult: validationResult
        )
    }

    private func executeRound(
        label: String,
        workspaceURL: URL,
        configuration: APIConfiguration,
        messages: inout [APIChatMessage],
        onLog: @escaping @Sendable (AgentLogEntry) async -> Void,
        onLearnedMemory: @escaping @Sendable (String) async -> Void
    ) async throws -> RoundResult {
        let responseText = try await aiService.completeChat(
            configuration: configuration,
            messages: messages
        )

        let roundPlan = try decodeRoundPlan(from: responseText)

        await onLog(
            AgentLogEntry(
                level: .info,
                title: label,
                detail: roundPlan.summary.isEmpty ? "模型已返回一组动作。" : roundPlan.summary
            )
        )

        guard !roundPlan.actions.isEmpty else {
            throw AgentAutomationError.invalidPlan("actions 为空。")
        }

        var toolOutputs: [String] = []
        var finishReason: String?
        var wroteFiles = false

        for action in roundPlan.actions.prefix(6) {
            let output = try await perform(
                action: action,
                workspaceURL: workspaceURL,
                onLog: onLog,
                onLearnedMemory: onLearnedMemory
            )
            toolOutputs.append(output)

            let normalizedType = action.type.lowercased()
            if normalizedType == "write_file" || normalizedType == "append_file" || normalizedType == "create_folder" {
                wroteFiles = true
            }

            if normalizedType == "finish" {
                finishReason = action.reason ?? roundPlan.summary
                break
            }
        }

        messages.append(
            APIChatMessage(
                role: "assistant",
                content: "\(label) 已规划并执行 \(min(roundPlan.actions.count, 6)) 个动作。"
            )
        )

        if finishReason == nil {
            messages.append(
                APIChatMessage(
                    role: "user",
                    content: """
                    工具执行结果如下：
                    \(toolOutputs.joined(separator: "\n\n"))

                    如果任务已经完成，请返回 finish。
                    如果还没完成，请继续返回下一轮 JSON。
                    """
                )
            )
        }

        return RoundResult(
            wroteFiles: wroteFiles,
            finishReason: finishReason
        )
    }

    private func perform(
        action: AgentAction,
        workspaceURL: URL,
        onLog: @escaping @Sendable (AgentLogEntry) async -> Void,
        onLearnedMemory: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        switch action.type.lowercased() {
        case "create_folder":
            guard let path = action.path else {
                throw AgentAutomationError.invalidPlan("create_folder 缺少 path。")
            }

            try workspaceService.createFolder(at: path, in: workspaceURL)
            await onLog(
                AgentLogEntry(
                    level: .success,
                    title: "创建文件夹",
                    detail: path
                )
            )
            return "create_folder \(path): success"

        case "write_file":
            guard let path = action.path, let content = action.content else {
                throw AgentAutomationError.invalidPlan("write_file 缺少 path 或 content。")
            }

            try workspaceService.writeFile(at: path, content: content, in: workspaceURL)
            await onLog(
                AgentLogEntry(
                    level: .success,
                    title: "写入文件",
                    detail: "\(path)\n\(summarizeContent(content))"
                )
            )
            return "write_file \(path): wrote \(content.count) chars"

        case "append_file":
            guard let path = action.path, let content = action.content else {
                throw AgentAutomationError.invalidPlan("append_file 缺少 path 或 content。")
            }

            try workspaceService.appendFile(at: path, content: content, in: workspaceURL)
            await onLog(
                AgentLogEntry(
                    level: .success,
                    title: "追加文件",
                    detail: "\(path)\n\(summarizeContent(content))"
                )
            )
            return "append_file \(path): appended \(content.count) chars"

        case "read_file":
            guard let path = action.path else {
                throw AgentAutomationError.invalidPlan("read_file 缺少 path。")
            }

            let content = try workspaceService.readFile(at: path, in: workspaceURL)
            await onLog(
                AgentLogEntry(
                    level: .info,
                    title: "读取文件",
                    detail: path
                )
            )
            return "read_file \(path):\n\(content)"

        case "run_command":
            guard let command = action.command else {
                throw AgentAutomationError.invalidPlan("run_command 缺少 command。")
            }

            let result = try await commandService.run(command: command, in: workspaceURL)
            await onLog(
                AgentLogEntry(
                    level: result.exitCode == 0 ? .success : .warning,
                    title: "运行命令",
                    detail: "\(command)\n\n\(result.combinedOutput)"
                )
            )
            return "run_command \(command): exit \(result.exitCode)\n\(result.combinedOutput)"

        case "remember":
            guard let content = action.content else {
                throw AgentAutomationError.invalidPlan("remember 缺少 content。")
            }

            await onLearnedMemory(content)
            await onLog(
                AgentLogEntry(
                    level: .info,
                    title: "更新长期记忆",
                    detail: content
                )
            )
            return "remember: saved"

        case "finish":
            let reason = action.reason ?? "任务已完成。"
            await onLog(
                AgentLogEntry(
                    level: .success,
                    title: "模型判断完成",
                    detail: reason
                )
            )
            return "finish: \(reason)"

        default:
            throw AgentAutomationError.invalidPlan("不支持的 action 类型：\(action.type)")
        }
    }

    private func validate(
        using validationCommand: ProjectValidationCommand,
        workspaceURL: URL,
        onLog: @escaping @Sendable (AgentLogEntry) async -> Void
    ) async throws -> LocalCommandResult {
        await onLog(
            AgentLogEntry(
                level: .info,
                title: "开始自检",
                detail: validationCommand.command
            )
        )

        let result = try await commandService.run(
            command: validationCommand.command,
            in: workspaceURL
        )

        await onLog(
            AgentLogEntry(
                level: result.exitCode == 0 ? .success : .warning,
                title: validationCommand.title,
                detail: result.combinedOutput
            )
        )

        return result
    }

    private func decodeRoundPlan(from rawText: String) throws -> RoundPlan {
        let jsonText = extractJSON(from: rawText)
        guard let data = jsonText.data(using: .utf8) else {
            throw AgentAutomationError.invalidPlan("无法解析 JSON 文本。")
        }

        do {
            return try JSONDecoder().decode(RoundPlan.self, from: data)
        } catch {
            throw AgentAutomationError.invalidPlan("JSON 解码失败：\(error.localizedDescription)\n原始返回：\(rawText)")
        }
    }

    private func extractJSON(from rawText: String) -> String {
        if let start = rawText.range(of: "```"),
           let end = rawText.range(of: "```", options: .backwards),
           start.lowerBound != end.lowerBound {
            let fenced = String(rawText[start.upperBound ..< end.lowerBound])
            if let jsonStart = fenced.firstIndex(of: "{"), let jsonEnd = fenced.lastIndex(of: "}") {
                return String(fenced[jsonStart ... jsonEnd])
            }
        }

        if let jsonStart = rawText.firstIndex(of: "{"), let jsonEnd = rawText.lastIndex(of: "}") {
            return String(rawText[jsonStart ... jsonEnd])
        }

        return rawText
    }

    private func summarizeContent(_ content: String) -> String {
        let lineCount = content.components(separatedBy: .newlines).count
        let preview = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(180)
        return "共 \(lineCount) 行，预览：\(preview)"
    }

    private static func initialPrompt(goal: String, snapshot: WorkspaceSnapshot) -> String {
        """
        目标：
        \(goal)

        当前工作区快照：
        \(snapshot.promptText)

        额外要求：
        1. 你在一个真实的本地工作区内工作，路径必须使用相对路径。
        2. 如需理解现有代码，先用 read_file。
        3. 写文件时必须给出完整文件内容。
        4. 如果当前工作区为空，你可以直接创建文件夹和项目文件。
        5. 当前应用会在你 finish 后自动做一次本地自检；如果自检失败，你还会收到错误输出继续修复。
        6. 如果用户之后再次运行同一个工作区，你需要基于原代码继续迭代。

        现在返回第 1 轮 JSON。
        """
    }

    private static let systemPrompt = """
    你是一个 macOS 本地编码智能体。你只能通过 JSON 动作操作工作区。
    你必须只返回一个 JSON 对象，不要使用 Markdown，不要添加解释文字。

    允许的 schema：
    {
      "summary": "本轮计划概述",
      "actions": [
        { "type": "read_file", "path": "Sources/App.swift", "reason": "读取现有实现" },
        { "type": "create_folder", "path": "Game/Assets", "reason": "创建资源目录" },
        { "type": "write_file", "path": "Game/Main.swift", "content": "完整文件内容", "reason": "写入主程序" },
        { "type": "append_file", "path": "README.md", "content": "追加内容", "reason": "补充说明" },
        { "type": "remember", "content": "用户偏好使用桌面工作区继续迭代", "reason": "保存长期偏好" },
        { "type": "run_command", "command": "swift build", "reason": "主动检查" },
        { "type": "finish", "reason": "任务已完成，可以进入自动自检" }
      ]
    }

    规则：
    - path 必须是相对工作区路径，不能是绝对路径。
    - 一轮最多返回 6 个 actions。
    - 优先修改现有代码，而不是重写整个项目。
    - 不要输出危险命令，例如 sudo、rm -rf、git reset --hard。
    - 如果需要更多代码上下文，使用 read_file。
    - 当你发现适合长期记住的用户偏好、项目约束或目录规则时，可以使用 remember。
    - 只有当你认为已经可以交给自动自检时，才返回 finish。
    """
}

private struct RoundPlan: Decodable {
    let summary: String
    let actions: [AgentAction]
}

private struct AgentAction: Decodable {
    let type: String
    let path: String?
    let content: String?
    let command: String?
    let reason: String?
}

private struct RoundResult {
    let wroteFiles: Bool
    let finishReason: String?
}
