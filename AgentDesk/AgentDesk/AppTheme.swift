import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.055, green: 0.063, blue: 0.082)
    static let panel = Color(red: 0.101, green: 0.117, blue: 0.149)
    static let panelSecondary = Color(red: 0.125, green: 0.145, blue: 0.184)
    static let sidebarTop = Color(red: 0.125, green: 0.196, blue: 0.286)
    static let sidebarBottom = Color(red: 0.066, green: 0.111, blue: 0.152)
    static let accent = Color(red: 0.360, green: 0.643, blue: 0.933)
    static let accentSoft = Color(red: 0.258, green: 0.470, blue: 0.721)
    static let success = Color(red: 0.255, green: 0.741, blue: 0.541)
    static let warning = Color(red: 0.984, green: 0.639, blue: 0.302)
    static let border = Color.white.opacity(0.085)
    static let subtleBorder = Color.white.opacity(0.040)
    static let secondaryText = Color.white.opacity(0.64)
    static let tertiaryText = Color.white.opacity(0.42)

    static let sidebarGradient = LinearGradient(
        colors: [sidebarTop, sidebarBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelGradient = LinearGradient(
        colors: [panelSecondary, panel],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    func appCard(fill: Color = AppTheme.panel) -> some View {
        background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}
