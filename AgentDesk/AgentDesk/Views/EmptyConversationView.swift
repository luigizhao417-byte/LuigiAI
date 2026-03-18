import SwiftUI

struct EmptyConversationView: View {
    @EnvironmentObject private var appState: AppState

    let openTaskCenter: () -> Void
    let openAgentCenter: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.36), AppTheme.warning.opacity(0.26)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 108, height: 108)

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text("开始构建")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(appState.configuration.isComplete ? "直接输入消息开始对话，或把想法丢进任务中心交给 Agent 执行。" : "先去设置里填好 API 信息，然后就能开始流式对话。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            HStack(spacing: 14) {
                Button {
                    openAgentCenter()
                } label: {
                    Label("打开 Agent", systemImage: "terminal")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.warning.opacity(0.84))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    openTaskCenter()
                } label: {
                    Label("打开任务中心", systemImage: "flag.checkered.2.crossed")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accent)
                        )
                }
                .buttonStyle(.plain)

                SettingsLink {
                    Label("打开设置", systemImage: "gearshape")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }
}
