import Foundation
import QuartzCore
import AppKit

public final class CircleRenderer {
    private var ball: BallState
    private var theme: Theme
    private var contentRotator: ContentRotator?
    private var displayLink: CVDisplayLink?
    private var isRunning = false
    private var lastFrameTime: CFTimeInterval = 0
    private let hostLayer: CALayer
    private var bounds: CGSize { hostLayer.bounds.size }
    private let settings: SettingsManager

    // Proximity fade state (set from outside)
    public var cursorPosition: CGPoint = CGPoint(x: -1000, y: -1000)

    public init(hostLayer: CALayer, bounds: CGSize) {
        self.hostLayer = hostLayer
        self.settings = SettingsManager.shared

        // Initialize ball
        self.ball = BallState(
            screenWidth: bounds.width,
            screenHeight: bounds.height,
            sizeMode: settings.ballSizeMode,
            sizeValue: settings.ballSize,
            speedPercentage: settings.ballSpeed
        )

        // Initialize theme
        self.theme = Self.createTheme(for: settings.theme)
        theme.setup(in: hostLayer)

        // Initialize content providers
        setupContentProviders()

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: SettingsManager.settingsChangedNotification,
            object: nil
        )
    }

    private static func createTheme(for themeID: ThemeID) -> Theme {
        switch themeID {
        case .minimal: return MinimalTheme()
        case .soft: return SoftTheme()
        }
    }

    private func setupContentProviders() {
        var providers: [ContentProvider] = []

        if settings.clockEnabled {
            providers.append(ClockProvider(use24Hour: settings.clockFormat24h))
        }
        if settings.systemInfoEnabled {
            providers.append(SystemInfoProvider(showBattery: settings.showBattery))
        }

        guard !providers.isEmpty else { return }

        contentRotator = ContentRotator(
            providers: providers,
            intervalSeconds: settings.contentRotationEnabled ? settings.contentRotationInterval : 9999
        )
        contentRotator?.start()
    }

    // MARK: - Animation

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        lastFrameTime = CACurrentMediaTime()

        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { isRunning = false; return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let renderer = Unmanaged<CircleRenderer>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async { [weak renderer] in
                renderer?.frame()
            }
            return kCVReturnSuccess
        }

        // passRetained keeps self alive as long as the display link context exists,
        // preventing use-after-free in the callback
        let pointer = Unmanaged.passRetained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, pointer)
        CVDisplayLinkStart(displayLink)
        self.displayLink = displayLink
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        if let displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
            // Balance the passRetained from start()
            Unmanaged.passUnretained(self).release()
        }
        contentRotator?.stop()
        theme.teardown()
    }

    private func frame() {
        guard isRunning else { return }
        let now = CACurrentMediaTime()
        let deltaTime = now - lastFrameTime
        lastFrameTime = now

        theme.tick(deltaTime: deltaTime)

        // Update motion via theme
        var motionState = MotionState(from: ball)
        motionState = theme.updateMotion(state: motionState, bounds: bounds)

        // Apply back to ball
        ball.x = motionState.x
        ball.y = motionState.y
        ball.vx = motionState.vx
        ball.vy = motionState.vy
        ball.hue = motionState.hue

        // Calculate opacity
        let baseOpacity = CGFloat(settings.ballOpacity) / 100.0
        let proximityOpacity = BallPhysics.proximityOpacity(
            ball: ball,
            cursorPosition: cursorPosition,
            fadeRadius: CGFloat(settings.proximityFadeRadius),
            fadeEnabled: settings.proximityFadeEnabled
        )
        let finalOpacity = baseOpacity * proximityOpacity

        // Update theme visuals
        theme.updateAppearance(
            position: CGPoint(x: ball.x, y: ball.y),
            size: ball.radius,
            hue: ball.hue,
            opacity: finalOpacity
        )

        // Update content
        let content = contentRotator?.currentProvider?.cachedData
        theme.setContent(content)
    }

    // MARK: - Settings

    @objc private func settingsChanged() {
        ball.updateRadius(
            screenWidth: bounds.width,
            screenHeight: bounds.height,
            sizeMode: settings.ballSizeMode,
            sizeValue: settings.ballSize
        )
        ball.updateSpeed(percentage: settings.ballSpeed)

        // Theme change - check if we need to switch
        let currentThemeId = (theme is MinimalTheme) ? ThemeID.minimal : ThemeID.soft
        if settings.theme != currentThemeId {
            theme.teardown()
            theme = Self.createTheme(for: settings.theme)
            theme.setup(in: hostLayer)
        }
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }
}
