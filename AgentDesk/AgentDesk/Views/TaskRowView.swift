import SwiftUI

struct TaskRowView: View {
    let task: AgentTask
    let linkedConversationTitle: String?
    let onRun: () -> Void
    let onToggleComplete: () -> Void
    let onDelete: () -> Void

    private var statusColor: Color {
        switch task.status {
        case .pending:
            return AppTheme.warning
        case .running:
            return AppTheme.accent
        case .completed:
            return AppTheme.success
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(task.status.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(statusColor.opacity(0.85))
                            )
                    }

                    Text(task.detail)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Text(task.updatedAt, style: .relative)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.tertiaryText)

                        if let linkedConversationTitle {
                            Text("会话：\(linkedConversationTitle)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }

                    if let lastError = task.lastError, !lastError.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.opacity(0.85))
                            Text(lastError)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.red.opacity(0.88))
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    onRun()
                } label: {
                    Label(task.status == .completed ? "再次执行" : "执行任务", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.88))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onToggleComplete()
                } label: {
                    Label(task.status == .completed ? "标记未完成" : "标记完成", systemImage: "checkmark.circle")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .padding(12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.22))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .appCard(fill: AppTheme.panel)
    }
}
