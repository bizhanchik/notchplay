import SwiftUI

struct GameMenuView: View {
    @EnvironmentObject private var viewModel: NotchViewModel
    @State private var selectedGame: GameType? = PreferencesManager.shared.enabledGameTypes.first

    private let itemWidth: CGFloat = 90
    private let itemSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            Text("NotchPlay")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, NotchLayout.safeAreaTop)
                .padding(.bottom, NotchLayout.menuTitleToButtonsSpacing)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(PreferencesManager.shared.enabledGameTypes, id: \.self) { gameType in
                        let isFocused = gameType == selectedGame

                        GameMenuItemView(gameType: gameType)
                            .frame(width: isFocused ? itemWidth + 16 : itemWidth,
                                   height: isFocused ? 88 : 72)
                            .opacity(isFocused ? 1.0 : 0.5)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedGame)
                            .onHover { hovering in
                                if hovering {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedGame = gameType
                                    }
                                }
                            }
                            .onTapGesture {
                                viewModel.startGame(gameType)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, NotchLayout.safeAreaHorizontal)
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.bottom, NotchLayout.safeAreaBottom)
        }
    }
}
