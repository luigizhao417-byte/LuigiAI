import Foundation

struct WorkspaceFileExcerpt {
    let path: String
    let totalLines: Int
    let includedLines: Int
    let content: String
}

struct WorkspaceSnapshot {
    let rootPath: String
    let fileList: [String]
    let excerpts: [WorkspaceFileExcerpt]
    let includedLineCount: Int

    var promptText: String {
        var sections: [String] = []
        sections.append("工作区路径：\(rootPath)")
        sections.append("文件列表：")

        if fileList.isEmpty {
            sections.append("(空工作区)")
        } else {
            sections.append(fileList.map { "- \($0)" }.joined(separator: "\n"))
        }

        sections.append("代码上下文（本次最多提供 \(includedLineCount) 行）：")

        if excerpts.isEmpty {
            sections.append("(暂未找到可读取的文本代码文件)")
        } else {
            for excerpt in excerpts {
                sections.append("""
                FILE: \(excerpt.path) [\(excerpt.includedLines)/\(excerpt.totalLines) lines]
                \(excerpt.content)
                END FILE
                """)
            }
        }

        return sections.joined(separator: "\n\n")
    }
}

enum WorkspaceServiceError: LocalizedError {
    case invalidPath
    case outsideWorkspace
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "工作区路径无效。"
        case .outsideWorkspace:
            return "目标路径超出了当前工作区。"
        case let .readFailed(path):
            return "读取文件失败：\(path)"
        case let .writeFailed(path):
            return "写入文件失败：\(path)"
        }
    }
}

struct WorkspaceService {
    private let fileManager = FileManager.default

    private let ignoredDirectories: Set<String> = [
        ".build",
        ".git",
        ".swiftpm",
        "Build",
        "DerivedData",
        "Pods",
        "node_modules",
        ".next"
    ]

    private let prioritizedExtensions: [String] = [
        "swift", "md", "txt", "json", "plist", "yaml", "yml", "xcconfig", "pbxproj", "html", "css", "js", "ts"
    ]

    func createDesktopWorkspace(named name: String = "AgentWorkspace") throws -> URL {
        let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        let workspaceURL = desktopURL.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        return workspaceURL.standardizedFileURL
    }

    func listFiles(in root: URL, maxFiles: Int = 400) throws -> [String] {
        let rootURL = root.standardizedFileURL
        guard fileManager.fileExists(atPath: rootURL.path) else {
            throw WorkspaceServiceError.invalidPath
        }

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
            errorHandler: nil
        ) else {
            throw WorkspaceServiceError.invalidPath
        }

        var files: [String] = []

        for case let itemURL as URL in enumerator {
            let relativePath = itemURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues?.isDirectory ?? false

            if isDirectory {
                if shouldSkipDirectory(itemURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            if shouldIncludeFile(itemURL) {
                files.append(relativePath)
                if files.count >= maxFiles {
                    break
                }
            }
        }

        return files.sorted(by: fileSortComparator)
    }

    func snapshot(
        in root: URL,
        lineBudget: Int = 5000,
        fileLimit: Int = 40
    ) throws -> WorkspaceSnapshot {
        let files = try listFiles(in: root, maxFiles: 400)
        var remainingLines = lineBudget
        var excerpts: [WorkspaceFileExcerpt] = []

        for path in files.prefix(fileLimit) {
            guard remainingLines > 0 else {
                break
            }

            let fileURL = try resolvedURL(for: path, in: root)
            guard let rawContent = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            let lines = rawContent.components(separatedBy: .newlines)
            let includedLines = min(lines.count, remainingLines)
            guard includedLines > 0 else {
                continue
            }

            let excerptBody = lines
                .prefix(includedLines)
                .enumerated()
                .map { "\($0.offset + 1): \($0.element)" }
                .joined(separator: "\n")

            let content: String
            if includedLines < lines.count {
                content = excerptBody + "\n... truncated ..."
            } else {
                content = excerptBody
            }

            excerpts.append(
                WorkspaceFileExcerpt(
                    path: path,
                    totalLines: lines.count,
                    includedLines: includedLines,
                    content: content
                )
            )

            remainingLines -= includedLines
        }

        return WorkspaceSnapshot(
            rootPath: root.standardizedFileURL.path,
            fileList: Array(files.prefix(220)),
            excerpts: excerpts,
            includedLineCount: lineBudget - remainingLines
        )
    }

    func createFolder(at relativePath: String, in root: URL) throws {
        let url = try resolvedURL(for: relativePath, in: root)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeFile(at relativePath: String, content: String, in root: URL) throws {
        let url = try resolvedURL(for: relativePath, in: root)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw WorkspaceServiceError.writeFailed(relativePath)
        }
    }

    func appendFile(at relativePath: String, content: String, in root: URL) throws {
        let url = try resolvedURL(for: relativePath, in: root)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        let merged = existing + separator + content

        do {
            try merged.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw WorkspaceServiceError.writeFailed(relativePath)
        }
    }

    func readFile(at relativePath: String, in root: URL, maxLines: Int = 1400) throws -> String {
        let url = try resolvedURL(for: relativePath, in: root)

        do {
            let rawContent = try String(contentsOf: url, encoding: .utf8)
            let lines = rawContent.components(separatedBy: .newlines)
            let preview = lines
                .prefix(maxLines)
                .enumerated()
                .map { "\($0.offset + 1): \($0.element)" }
                .joined(separator: "\n")

            if lines.count > maxLines {
                return preview + "\n... truncated ..."
            }

            return preview
        } catch {
            throw WorkspaceServiceError.readFailed(relativePath)
        }
    }

    private func resolvedURL(for relativePath: String, in root: URL) throws -> URL {
        let trimmedPath = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw WorkspaceServiceError.invalidPath
        }

        let rootURL = root.standardizedFileURL
        let targetURL = rootURL.appendingPathComponent(trimmedPath).standardizedFileURL
        let rootPath = rootURL.path
        let targetPath = targetURL.path

        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else {
            throw WorkspaceServiceError.outsideWorkspace
        }

        return targetURL
    }

    private func shouldSkipDirectory(_ name: String) -> Bool {
        if ignoredDirectories.contains(name) {
            return true
        }

        if name.hasPrefix(".") && name != ".xcodeproj" {
            return true
        }

        let ignoredExtensions = ["app", "framework", "xcarchive", "dSYM"]
        return ignoredExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    private func shouldIncludeFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if prioritizedExtensions.contains(ext) {
            return true
        }

        let name = url.lastPathComponent.lowercased()
        let exactMatches = ["package.swift", "readme", "readme.md", ".gitignore"]
        return exactMatches.contains(name)
    }

    private func fileSortComparator(_ lhs: String, _ rhs: String) -> Bool {
        let lhsDepth = lhs.split(separator: "/").count
        let rhsDepth = rhs.split(separator: "/").count

        if lhsDepth != rhsDepth {
            return lhsDepth < rhsDepth
        }

        let lhsPriority = priority(for: lhs)
        let rhsPriority = priority(for: rhs)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        return lhs < rhs
    }

    private func priority(for path: String) -> Int {
        let ext = (path as NSString).pathExtension.lowercased()
        if let index = prioritizedExtensions.firstIndex(of: ext) {
            return index
        }
        return prioritizedExtensions.count + 1
    }
}
