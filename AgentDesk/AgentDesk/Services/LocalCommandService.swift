import Foundation

struct LocalCommandResult {
    let command: String
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        if stdout.isEmpty && stderr.isEmpty {
            return "无输出"
        }

        var sections: [String] = []
        if !stdout.isEmpty {
            sections.append("STDOUT:\n\(stdout)")
        }
        if !stderr.isEmpty {
            sections.append("STDERR:\n\(stderr)")
        }
        return sections.joined(separator: "\n\n")
    }
}

struct LocalCommandService {
    func run(
        command: String,
        in directory: URL,
        timeout: TimeInterval = 240
    ) async throws -> LocalCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.currentDirectoryURL = directory
                process.environment = ProcessInfo.processInfo.environment
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }

                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
                process.waitUntilExit()
                timeoutWorkItem.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = trim(String(data: stdoutData, encoding: .utf8) ?? "")
                let stderr = trim(String(data: stderrData, encoding: .utf8) ?? "")

                continuation.resume(
                    returning: LocalCommandResult(
                        command: command,
                        exitCode: process.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    )
                )
            }
        }
    }

    private func trim(_ text: String, maxCharacters: Int = 12000) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else {
            return trimmed
        }

        let prefix = trimmed.prefix(maxCharacters)
        return String(prefix) + "\n... output truncated ..."
    }
}
