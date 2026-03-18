import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    @State private var draftText = ""
    @State private var isTaskCenterPresented = false
    @State private var isAgentCenterPresented = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()

            Rectangle()
                .fill(AppTheme.subtleBorder)
                .frame(width: 1)

            ChatDetailView(
                draftText: $draftText,
                isTaskCenterPresented: $isTaskCenterPresented,
                isAgentCenterPresented: $isAgentCenterPresented
            )
        }
        .background(AppTheme.canvas)
        .sheet(isPresented: $isTaskCenterPresented) {
            TaskCenterView(prefillText: $draftText)
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 660)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $isAgentCenterPresented) {
            AgentCenterView(prefillGoal: $draftText)
                .environmentObject(appState)
                .frame(minWidth: 920, minHeight: 760)
                .preferredColorScheme(.dark)
        }
    }
}
