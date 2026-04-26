import AppKit
import CircleKit

final class CircleOverlayView: NSView {
    private var renderer: CircleRenderer?
    private var cursorPollTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimation() {
        guard let layer else { return }

        renderer = CircleRenderer(
            hostLayer: layer,
            bounds: CGSize(width: bounds.width, height: bounds.height)
        )
        renderer?.start()

        // Poll cursor position. NSEvent.addGlobalMonitorForEvents only fires for
        // events going to *other* apps, so it stops updating when our own app
        // becomes frontmost (e.g., when Settings is open) — freezing the
        // proximity fade. NSEvent.mouseLocation works regardless of focus.
        cursorPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, let screen = self.window?.screen else { return }
            let screenPoint = NSEvent.mouseLocation
            let windowPoint = CGPoint(
                x: screenPoint.x - screen.frame.origin.x,
                y: screenPoint.y - screen.frame.origin.y
            )
            self.renderer?.cursorPosition = windowPoint
        }
    }

    func stopAnimation() {
        renderer?.stop()
        renderer = nil
        cursorPollTimer?.invalidate()
        cursorPollTimer = nil
    }
}
