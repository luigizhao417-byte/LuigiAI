import SwiftUI

struct ConversationRowView: View {
    let conversation: ChatConversation
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                    .foregroundStyle(isSelected ? .white : AppTheme.secondaryText)
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text(conversation.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(conversation.previewText)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack {
                Text(conversation.updatedAt, style: .relative)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.tertiaryText)

                Spacer()

                Text("\(conversation.messages.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.secondaryText)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.16) : AppTheme.subtleBorder, lineWidth: 1)
                )
        )
    }
}
