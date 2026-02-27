import AppKit
import Combine
import SwiftUI

final class NotchWindowController: NSWindowController {

    let viewModel: NotchViewModel
    private let inputManager: InputManager
    private var cancellables = Set<AnyCancellable>()
    private var currentTrackingArea: NSTrackingArea?

    init(screen: NSScreen? = NSScreen.main) {
        let vm = NotchViewModel(screen: screen)
        self.viewModel = vm
        self.inputManager = InputManager(viewModel: vm)

        // Window is always at expanded size - SwiftUI handles visual sizing
        let expandedSize = NotchLayout.expandedSize
        let windowSize = NotchLayout.windowSize(for: expandedSize)
        let screenFrame = screen?.frame ?? NSScreen.main!.frame

        let origin = CGPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.maxY - windowSize.height
        )

        let panel = NotchPanel(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let rootView = RootNotchView()
            .environmentObject(vm)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []

        let containerView = NotchTrackingContainerView(frame: NSRect(origin: .zero, size: windowSize))
        containerView.viewModel = vm
        containerView.embed(hostingView)
        panel.contentView = containerView

        super.init(window: panel)

        setupTracking()
        setupTrackingAreaObserver()
        setupScreenChangeObserver()
        inputManager.startMonitoring()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Tracking Area

    private func setupTracking() {
        updateTrackingArea()
    }

    private func setupTrackingAreaObserver() {
        viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateTrackingArea()
                // При переходе в игру делаем окно ключевым, чтобы первое нажатие сразу
                // обрабатывалось (иначе первый клик тратится на "захват фокуса", второй - на ввод)
                if case .playingGame = state {
                    self?.window?.makeKey()
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .store(in: &cancellables)
    }

    private func updateTrackingArea() {
        guard let contentView = window?.contentView else { return }

        if let existing = currentTrackingArea {
            contentView.removeTrackingArea(existing)
            currentTrackingArea = nil
        }

        let rect: NSRect
        switch viewModel.state {
        case .compact:
            let compact = viewModel.closedNotchSize
            let bounds = contentView.bounds
            // Контейнер использует isFlipped, y=0 - верх
            let isFlipped = (contentView as? NotchTrackingContainerView)?.isFlipped ?? false
            rect = NSRect(
                x: (bounds.width - compact.width) / 2,
                y: isFlipped ? 0 : (bounds.height - compact.height),
                width: compact.width,
                height: compact.height
            )
        case .expandedMenu, .playingGame:
            rect = contentView.bounds
        }

        let trackingArea = NSTrackingArea(
            rect: rect,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        currentTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        if viewModel.state == .compact {
            // Доп. проверка: курсор должен быть в compact-зоне (защита от ложных событий)
            guard let contentView = window?.contentView else { return }
            let loc = contentView.convert(event.locationInWindow, from: nil)
            let compact = viewModel.closedNotchSize
            let bounds = contentView.bounds
            let isFlipped = (contentView as? NotchTrackingContainerView)?.isFlipped ?? false
            let notchRect = NSRect(
                x: (bounds.width - compact.width) / 2,
                y: isFlipped ? 0 : (bounds.height - compact.height),
                width: compact.width,
                height: compact.height
            )
            guard notchRect.contains(loc) else { return }
        }
        viewModel.handleMouseEnter()
    }

    override func mouseExited(with event: NSEvent) {
        viewModel.handleMouseExit()
    }


    // MARK: - Screen Changes

    private func setupScreenChangeObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionWindow()
            }
            .store(in: &cancellables)
    }

    private func repositionWindow() {
        guard let panel = window, let screen = NSScreen.main else { return }

        let windowSize = panel.frame.size
        let origin = CGPoint(
            x: screen.frame.midX - windowSize.width / 2,
            y: screen.frame.maxY - windowSize.height
        )
        panel.setFrame(NSRect(origin: origin, size: windowSize), display: true)

        viewModel.closedNotchSize = NotchLayout.compactSize(for: screen)
    }
}
