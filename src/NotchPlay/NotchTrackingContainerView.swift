import AppKit

/// Контейнер, который в compact-режиме принимает hit только в области notch,
/// чтобы окно не реагировало на наведение вне видимого notch.
final class NotchTrackingContainerView: NSView {

    var viewModel: NotchViewModel?  // strong - viewModel живёт в window controller
    private var hostingView: NSView?

    override var isFlipped: Bool { true }

    func embed(_ view: NSView) {
        hostingView?.removeFromSuperview()
        hostingView = view
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return nil }  // без viewModel - прозрачно для hit

        switch vm.state {
        case .compact:
            let compact = vm.closedNotchSize
            let notchRect = NSRect(
                x: (bounds.width - compact.width) / 2,
                y: 0,
                width: compact.width,
                height: compact.height
            )
            return notchRect.contains(point) ? super.hitTest(point) : nil
        case .expandedMenu, .playingGame:
            return super.hitTest(point)
        }
    }
}
