import SwiftUI

struct GameMenuItemView: View {
    let gameType: GameType
    @State private var hoverRotation: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            gameIcon
                .rotationEffect(.degrees(hoverRotation))

            Text(gameType.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.06))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoverRotation = -8
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.3).delay(0.15)) {
                    hoverRotation = 0
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hoverRotation = 0
                }
            }
        }
    }

    @ViewBuilder
    private var gameIcon: some View {
        if let assetIcon = gameType.assetIcon {
            Image(assetIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: gameType.icon)
                .font(.system(size: 28))
                .foregroundStyle(.white)
        }
    }
}
