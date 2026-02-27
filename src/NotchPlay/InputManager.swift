import AppKit

final class InputManager {

    private weak var viewModel: NotchViewModel?
    private var keyDownMonitor: Any?
    private var mouseDownMonitor: Any?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func startMonitoring() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let vm = self.viewModel else { return event }

            // Escape always works - exit game or collapse menu
            if event.keyCode == 53 {
                switch vm.state {
                case .playingGame:
                    vm.exitGame()
                    return nil
                case .expandedMenu:
                    vm.close()
                    return nil
                default:
                    return event
                }
            }

            // Game input
            guard case .playingGame(let gameType) = vm.state else { return event }

            // Snake and Pong handle their own arrow key input - don't steal it
            let arrowKeys: Set<UInt16> = [123, 124, 125, 126] // left, right, down, up
            if (gameType == .snake || gameType == .pong) && arrowKeys.contains(event.keyCode) {
                return event
            }

            switch event.keyCode {
            case 49, 126: // Spacebar, Up arrow
                NotificationCenter.default.post(name: .gameJumpInput, object: nil)
                return nil
            default:
                return event
            }
        }

        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let vm = self.viewModel else { return event }
            guard case .playingGame = vm.state else { return event }

            // Post jump input but DON'T consume the event -
            // let it pass through so the exit (X) button still works
            NotificationCenter.default.post(name: .gameJumpInput, object: nil)
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
    }

    nonisolated deinit {
    }
}
