import ScreenSaver
import CircleKit

final class CircleSaverView: ScreenSaverView {
    private var renderer: CircleRenderer?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        animationTimeInterval = 1.0 / 60.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        animationTimeInterval = 1.0 / 60.0
    }

    override func startAnimation() {
        super.startAnimation()

        guard let layer else { return }
        layer.backgroundColor = NSColor.black.cgColor

        renderer = CircleRenderer(
            hostLayer: layer,
            bounds: CGSize(width: bounds.width, height: bounds.height)
        )
        renderer?.start()
    }

    override func stopAnimation() {
        renderer?.stop()
        renderer = nil
        super.stopAnimation()
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
