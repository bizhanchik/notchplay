import SwiftUI

struct RootNotchView: View {
    @EnvironmentObject private var viewModel: NotchViewModel

    var body: some View {
        NotchContainerView {
            switch viewModel.state {
            case .compact:
                CompactNotchContent()

            case .expandedMenu:
                GameMenuView()
                    .transition(.opacity)

            case .playingGame(let gameType):
                GameContainerView(gameType: gameType)
                    .transition(.opacity)
            }
        }
    }
}

private struct CompactNotchContent: View {
    var body: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.7))
    }
}
