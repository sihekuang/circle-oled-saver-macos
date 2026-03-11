import AppKit
import CircleKit

final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private var overlayViews: [CircleOverlayView] = []

    func show() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.hasShadow = false

            let overlayView = CircleOverlayView(frame: screen.frame)
            window.contentView = overlayView

            window.orderFrontRegardless()
            windows.append(window)
            overlayViews.append(overlayView)

            overlayView.startAnimation()
        }
    }

    func dismiss() {
        overlayViews.forEach { $0.stopAnimation() }
        windows.forEach { $0.close() }
        windows.removeAll()
        overlayViews.removeAll()
    }
}
