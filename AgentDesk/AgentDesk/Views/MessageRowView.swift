import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    let isStreamingPlaceholder: Bool

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            if isUser {
                Spacer(minLength: 140)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: isUser ? "person.crop.circle.fill" : "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isUser ? AppTheme.accent : AppTheme.warning)

                    Text(isUser ? "你" : "AI")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(message.createdAt, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if isStreamingPlaceholder && message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)

                            Text("正在逐步生成...")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } else {
                        Text(message.content.isEmpty ? " " : message.content)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isUser ? AppTheme.accent.opacity(0.80) : AppTheme.panelSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(isUser ? Color.white.opacity(0.10) : AppTheme.border, lineWidth: 1)
                        )
                )
                .frame(maxWidth: 760, alignment: .leading)
            }

            if !isUser {
                Spacer(minLength: 140)
            }
        }
    }
}
