import SwiftUI

struct TaskCenterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @Binding var prefillText: String

    @State private var taskTitle = ""
    @State private var taskDetail = ""
    @State private var didSeedPrefill = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("任务中心")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("把当前思路存成任务，或直接交给模型执行。执行中的任务会自动写入会话。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("新建任务")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))

                TextField("任务标题（可选）", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    )

                TextEditor(text: $taskDetail)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    )

                HStack {
                    Text("提示：如果聊天输入框里已经有内容，打开这里时会自动带进来。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Button {
                        if appState.addTask(title: taskTitle, detail: taskDetail) {
                            if taskDetail.trimmingCharacters(in: .whitespacesAndNewlines) == prefillText.trimmingCharacters(in: .whitespacesAndNewlines) {
                                prefillText = ""
                            }
                            taskTitle = ""
                            taskDetail = ""
                        }
                    } label: {
                        Label("创建任务", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .appCard(fill: AppTheme.panelSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    taskSection(title: "待处理", tasks: appState.pendingTasks)
                    taskSection(title: "已完成", tasks: appState.completedTasks)
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [AppTheme.canvas, AppTheme.sidebarBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            seedPrefillIfNeeded()
        }
    }

    @ViewBuilder
    private func taskSection(title: String, tasks: [AgentTask]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if tasks.isEmpty {
                Text("暂时没有\(title == "待处理" ? "待处理" : "已完成")任务。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            linkedConversationTitle: appState.conversationTitle(for: task.linkedConversationID),
                            onRun: {
                                _ = appState.runTask(task)
                            },
                            onToggleComplete: {
                                appState.toggleTaskCompletion(task)
                            },
                            onDelete: {
                                appState.deleteTask(task)
                            }
                        )
                    }
                }
            }
        }
    }

    private func seedPrefillIfNeeded() {
        guard !didSeedPrefill else {
            return
        }

        let trimmedPrefill = prefillText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrefill.isEmpty else {
            didSeedPrefill = true
            return
        }

        taskDetail = trimmedPrefill
        taskTitle = AppState.condensedTitle(from: trimmedPrefill, fallback: "新任务")
        didSeedPrefill = true
    }
}
