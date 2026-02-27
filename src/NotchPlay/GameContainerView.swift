import SwiftUI

struct GameContainerView: View {
    let gameType: GameType
    @EnvironmentObject private var viewModel: NotchViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            gameView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, NotchLayout.safeAreaTop)
                .padding(.bottom, NotchLayout.safeAreaBottom)
                .padding(.horizontal, NotchLayout.safeAreaHorizontal)

            Button(action: { viewModel.exitGame() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .padding(.top, NotchLayout.safeAreaTop - 4)
            .padding(.trailing, NotchLayout.safeAreaHorizontal)
        }
    }

    @ViewBuilder
    private var gameView: some View {
//        switch gameType {
//        case .dino:
//            DinoGameView()
//        case .flappy:
//            FlappyGameView()
//        }
        
        if gameType == .dino {
            DinoGameView()
        } else if gameType == .flappy {
            FlappyGameView()
        } else if gameType == .stack {
            StackGameView()
        } else if gameType == .pong {
            PongGameView()
        } else if gameType == .snake {
            SnakeGameView()
        } else if gameType == .breakout {
            BreakoutGameView()
        }
    }
}
