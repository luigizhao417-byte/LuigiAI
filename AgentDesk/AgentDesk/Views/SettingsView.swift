import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var apiURL = ""
    @State private var apiKey = ""
    @State private var modelName = ""
    @State private var revealAPIKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("API 设置")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("支持 OpenAI / DeepSeek 兼容接口。你可以填完整接口地址，也可以填到 `v1` 为止，应用会自动补全到 `chat/completions`。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    settingField(
                        title: "API URL",
                        hint: "例如 https://api.openai.com/v1/chat/completions",
                        text: $apiURL
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("API Key")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))

                            Spacer()

                            Button(revealAPIKey ? "隐藏" : "显示") {
                                revealAPIKey.toggle()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                        }

                        Group {
                            if revealAPIKey {
                                TextField("sk-...", text: $apiKey)
                            } else {
                                SecureField("sk-...", text: $apiKey)
                            }
                        }
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
                    }

                    settingField(
                        title: "模型名称",
                        hint: "例如 gpt-4o-mini / deepseek-chat",
                        text: $modelName
                    )
                }
                .padding(22)
                .background(AppTheme.panelGradient)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )

                HStack(spacing: 14) {
                    Button {
                        appState.updateConfiguration(url: apiURL, key: apiKey, model: modelName)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "tray.and.arrow.down.fill")
                            Text("保存配置")
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)

                    Text(appState.configuration.isComplete ? "当前配置完整，可直接发起请求。" : "还没有填写完整配置。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("兼容说明")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("1. OpenAI 常用地址：`https://api.openai.com/v1/chat/completions`")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("2. DeepSeek 常用地址：`https://api.deepseek.com/chat/completions`")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("3. 如果你接的是自建兼容网关，也可以直接填完整 POST 地址。")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))

                VStack(alignment: .leading, spacing: 16) {
                    Text("长期记忆")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("应用会从你的输入和 Agent 任务里学习长期偏好，并在后续对话和自动化任务里继续使用。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)

                    if appState.recentMemories.isEmpty {
                        Text("还没有学习到长期记忆。")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach(appState.recentMemories) { memory in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(memory.content)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("来源：\(memory.source) · \(memory.updatedAt, style: .relative)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    appState.removeMemory(memory)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(10)
                                        .foregroundStyle(.white)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.red.opacity(0.25))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(AppTheme.border, lineWidth: 1)
                                    )
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        Button(role: .destructive) {
                            appState.clearLearnedMemories()
                        } label: {
                            Label("清空学习记忆", systemImage: "brain.head.profile")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.red.opacity(0.25))
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("数据管理")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("这个按钮只会清空本地会话、任务、日志、学习记忆和工作区引用，不会删除 API 配置。API 如需删除，请把设置里的字段清空后再点保存。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        appState.clearLocalDataKeepingAPI()
                    } label: {
                        Label("清空本地数据（保留 API）", systemImage: "trash.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.red.opacity(0.28))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
        }
        .background(
            LinearGradient(
                colors: [AppTheme.sidebarBottom, AppTheme.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear(perform: syncFromState)
    }

    private func settingField(title: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            TextField(hint, text: text)
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
        }
    }

    private func syncFromState() {
        apiURL = appState.configuration.apiURL
        apiKey = appState.configuration.apiKey
        modelName = appState.configuration.modelName
    }
}
