import AppKit
import Combine
import SwiftUI

// MARK: - State Types

enum NotchState: Equatable {
    case compact
    case expandedMenu
    case playingGame(GameType)
}

enum GameType: String, CaseIterable, Equatable {
    case dino = "Dino Runner"
    case flappy = "Flappy Bird"
    case stack = "Stack"
    case pong = "Pong"
    case snake = "Snake"
    case breakout = "Breakout"

    var icon: String {
        switch self {
        case .dino: "figure.run"
        case .flappy: "bird.fill"
        case .stack: "square.stack.3d.up.fill"
        case .pong: "gamecontroller.fill"
        case .snake: "line.3.horizontal"
        case .breakout: "rectangle.split.3x3"
        }
    }

    /// Asset catalog image name for games that have custom icons (nil = use SF Symbol)
    var assetIcon: String? {
        switch self {
        case .dino: "dino_idle"
        case .flappy: "bird_1"
        case .stack: nil
        case .pong: "pong_logo"
        case .snake: "snake_logo"
        case .breakout: "breakout_logo"
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let gameJumpInput = Notification.Name("gameJumpInput")
}

// MARK: - Layout Constants

enum NotchLayout {
    static let fallbackCompactSize = CGSize(width: 220, height: 44)
    static let expandedSize = CGSize(width: 420, height: 180)
    static let shadowPadding: CGFloat = 12

    /// Safe area insets для меню и игр (отступ от краёв notch)
    static let safeAreaTop: CGFloat = 40
    static let safeAreaBottom: CGFloat = 24
    static let safeAreaHorizontal: CGFloat = 28
    static let menuTitleToButtonsSpacing: CGFloat = 16
    static let menuButtonsSpacing: CGFloat = 12

    static let closedCornerRadii: (top: CGFloat, bottom: CGFloat) = (6, 14)
    static let openedCornerRadii: (top: CGFloat, bottom: CGFloat) = (19, 24)

    static let springResponse: Double = 0.4
    static let springDamping: Double = 0.78
    static let collapseDelay: UInt64 = 300_000_000 // 300ms in nanoseconds

    static func compactSize(for screen: NSScreen?) -> CGSize {
        guard let screen else { return fallbackCompactSize }

        var width: CGFloat = 185
        var height: CGFloat = 44

        if let leftArea = screen.auxiliaryTopLeftArea?.width,
           let rightArea = screen.auxiliaryTopRightArea?.width {
            width = screen.frame.width - leftArea - rightArea + 4
        }

        if screen.safeAreaInsets.top > 0 {
            height = screen.safeAreaInsets.top
        } else {
            height = screen.frame.maxY - screen.visibleFrame.maxY
        }

        return CGSize(width: max(width, 120), height: max(height, 24))
    }

    static func windowSize(for notchSize: CGSize) -> CGSize {
        CGSize(width: notchSize.width, height: notchSize.height + shadowPadding)
    }
}

// MARK: - ViewModel

class NotchViewModel: ObservableObject {
    @Published private(set) var state: NotchState = .compact
    @Published var notchSize: CGSize
    @Published var closedNotchSize: CGSize

    private var collapseTask: Task<Void, Never>?
    private var hapticCooldownTask: Task<Void, Never>?
    private(set) var isHapticEnabled = true

    init(screen: NSScreen? = NSScreen.main) {
        let compact = NotchLayout.compactSize(for: screen)
        self.notchSize = compact
        self.closedNotchSize = compact
    }

    var currentCornerRadii: (top: CGFloat, bottom: CGFloat) {
        switch state {
        case .compact:
            NotchLayout.closedCornerRadii
        case .expandedMenu, .playingGame:
            NotchLayout.openedCornerRadii
        }
    }

    var isExpanded: Bool {
        state != .compact
    }

    // MARK: - Hover

    func handleMouseEnter() {
        collapseTask?.cancel()
        collapseTask = nil
        hapticCooldownTask?.cancel()
        hapticCooldownTask = nil
        isHapticEnabled = true

        if state == .compact && PreferencesManager.shared.activationMode == .hover {
            open()
        }
    }

    func handleMouseExit() {
        isHapticEnabled = false  // haptic отключается сразу при уходе курсора

        if state == .expandedMenu {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: NotchLayout.collapseDelay)
                guard let self, self.state == .expandedMenu else { return }
                self.close()
            }
        }
    }

    // MARK: - State Transitions

    func open() {
        guard state == .compact else { return }
        if isHapticEnabled { HapticManager.shared.playTransition() }

        withAnimation(.spring(response: NotchLayout.springResponse, dampingFraction: NotchLayout.springDamping)) {
            notchSize = NotchLayout.expandedSize
            state = .expandedMenu
        }
    }

    func close() {
        guard state == .expandedMenu else { return }

        collapseTask?.cancel()
        collapseTask = nil

        withAnimation(.spring(response: NotchLayout.springResponse, dampingFraction: NotchLayout.springDamping)) {
            notchSize = closedNotchSize
            state = .compact
        }

        // Включаем haptic снова после завершения анимации закрытия
        hapticCooldownTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6 сек
            await MainActor.run { [weak self] in
                self?.isHapticEnabled = true
                self?.hapticCooldownTask = nil
            }
        }
    }

    func startGame(_ game: GameType) {
        guard state == .expandedMenu else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            state = .playingGame(game)
        }
    }

    func exitGame() {
        guard case .playingGame = state else { return }

        withAnimation(.spring(response: NotchLayout.springResponse, dampingFraction: NotchLayout.springDamping)) {
            state = .expandedMenu
        }
    }
}
