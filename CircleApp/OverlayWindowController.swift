import AppKit
import CircleKit

final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private var overlayViews: [CircleOverlayView] = []

    func show() {
        for (i, screen) in NSScreen.screens.enumerated() {
            NSLog("[OverlayWindow] Screen %d: frame=%@ visibleFrame=%@ backingScaleFactor=%.1f",
                  i, NSStringFromRect(screen.frame), NSStringFromRect(screen.visibleFrame), screen.backingScaleFactor)

            let screenRect = NSRect(origin: .zero, size: screen.frame.size)
            let window = NSWindow(
                contentRect: screenRect,
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

            let overlayView = CircleOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.contentView = overlayView

            window.orderFrontRegardless()

            NSLog("[OverlayWindow] Screen %d: window.frame=%@ contentView.frame=%@ contentView.bounds=%@ layer.bounds=%@",
                  i, NSStringFromRect(window.frame),
                  NSStringFromRect(overlayView.frame),
                  NSStringFromRect(overlayView.bounds),
                  NSStringFromRect(overlayView.layer?.bounds ?? .zero))

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
