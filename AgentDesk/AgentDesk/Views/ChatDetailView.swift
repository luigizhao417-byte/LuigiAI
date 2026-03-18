import SwiftUI

struct ChatDetailView: View {
    @EnvironmentObject private var appState: AppState

    @Binding var draftText: String
    @Binding var isTaskCenterPresented: Bool
    @Binding var isAgentCenterPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 18)

            if let conversation = appState.selectedConversation, !conversation.messages.isEmpty {
                messageList(for: conversation)
            } else {
                EmptyConversationView(
                    openTaskCenter: {
                        isTaskCenterPresented = true
                    },
                    openAgentCenter: {
                        isAgentCenterPresented = true
                    }
                )
            }

            composerSection
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.22), AppTheme.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert(
            "请求失败",
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        appState.dismissError()
                    }
                }
            )
        ) {
            Button("知道了") {
                appState.dismissError()
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.selectedConversation?.title ?? "开始构建")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let statusMessage = appState.statusMessage, !statusMessage.isEmpty {
                    HStack(spacing: 8) {
                        if appState.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }

                        Text(statusMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } else {
                    Text(appState.configuration.isComplete ? "支持 OpenAI / DeepSeek 格式接口，回复将流式刷新。" : "先打开设置填好 API 配置，然后就可以开始对话。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    isAgentCenterPresented = true
                } label: {
                    Label("Agent", systemImage: "terminal")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.warning.opacity(0.78))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    isTaskCenterPresented = true
                } label: {
                    Label("任务", systemImage: "checklist")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    _ = appState.createConversationAndSelect()
                } label: {
                    Label("新会话", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.88))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func messageList(for conversation: ChatConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(conversation.messages) { message in
                        MessageRowView(
                            message: message,
                            isStreamingPlaceholder: appState.isLoading &&
                                conversation.messages.last?.id == message.id &&
                                message.role == .assistant
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToBottom(proxy: proxy, in: conversation)
            }
            .onChange(of: conversation.messages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, in: conversation)
            }
            .onChange(of: conversation.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy, in: conversation)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var composerSection: some View {
        ComposerView(
            draftText: $draftText,
            isSending: appState.isLoading,
            canSend: !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                appState.configuration.isComplete &&
                !appState.isAgentRunning,
            onSend: {
                let currentDraft = draftText
                if appState.sendMessage(currentDraft) {
                    draftText = ""
                }
            },
            onOpenTasks: {
                isTaskCenterPresented = true
            },
            onCancel: {
                appState.cancelStreaming()
            }
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, in conversation: ChatConversation) {
        guard let lastID = conversation.messages.last?.id else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}
