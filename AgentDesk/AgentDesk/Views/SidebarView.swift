import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accentSoft],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)

                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AgentDesk")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("你的 macOS AI Agent 工作台")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                Button {
                    _ = appState.createConversationAndSelect()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                        Text("新建会话")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent.opacity(0.96), AppTheme.accentSoft.opacity(0.92)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("会话")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))

                    Spacer()

                    Text("\(appState.conversations.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.conversations) { conversation in
                            ConversationRowView(
                                conversation: conversation,
                                isSelected: appState.selectedConversationID == conversation.id
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    appState.deleteConversation(conversation)
                                } label: {
                                    Label("删除会话", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                appState.selectConversation(conversation)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checklist.checked")
                        .foregroundStyle(AppTheme.warning)
                    Text("待办任务 \(appState.pendingTaskCount)")
                        .foregroundStyle(.white.opacity(0.88))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }

                SettingsLink {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                        Text("设置")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                        )
                }
                .buttonStyle(.plain)

                if let workspacePath = appState.workspacePath {
                    Text("工作区：\(workspacePath)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(22)
        .frame(width: 320, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.sidebarGradient)
    }
}
