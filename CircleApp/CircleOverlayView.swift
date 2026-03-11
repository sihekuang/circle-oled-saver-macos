import AppKit
import CircleKit

final class CircleOverlayView: NSView {
    private var renderer: CircleRenderer?
    private var mouseMonitor: Any?

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

        // Track mouse for proximity fade
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
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
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        mouseMonitor = nil
    }
}
