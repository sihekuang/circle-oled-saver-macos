# Circle OLED Saver — Native macOS Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app + screen saver plugin that displays a bouncing animated circle with rotating content to prevent OLED burn-in, porting the existing Electron app to Swift.

**Architecture:** Local Swift package (CircleKit) contains shared rendering (Core Animation), ball physics, themes, and content providers. Menu bar app target (AppKit) creates transparent overlay windows, monitors idle time, and hosts SwiftUI settings. Screen saver target (.saver) subclasses ScreenSaverView and reuses CircleKit.

**Tech Stack:** Swift 5.9+, macOS 14+, AppKit, SwiftUI, Core Animation, IOKit, Carbon (hotkeys), ScreenSaver framework

**Reference:** Electron source at `~/Documents/Projects/oled-saver-electron/src/`

---

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `CircleOLEDSaver.xcodeproj` (via xcodegen or manual)
- Create: `project.yml` (XcodeGen spec)
- Create: `CircleKit/Package.swift`
- Create: `CircleKit/Sources/CircleKit/CircleKit.swift` (placeholder)
- Create: `CircleApp/Info.plist`
- Create: `CircleApp/CircleApp.entitlements`
- Create: `CircleSaver/Info.plist`

**Step 1: Create directory structure**

```bash
mkdir -p CircleKit/Sources/CircleKit
mkdir -p CircleKit/Tests/CircleKitTests
mkdir -p CircleApp/Resources
mkdir -p CircleSaver
```

**Step 2: Create CircleKit Package.swift**

```swift
// CircleKit/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CircleKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CircleKit", targets: ["CircleKit"]),
    ],
    targets: [
        .target(name: "CircleKit"),
        .testTarget(name: "CircleKitTests", dependencies: ["CircleKit"]),
    ]
)
```

**Step 3: Create placeholder CircleKit.swift**

```swift
// CircleKit/Sources/CircleKit/CircleKit.swift
import Foundation
```

**Step 4: Create project.yml for XcodeGen**

```yaml
name: CircleOLEDSaver
options:
  bundleIdPrefix: com.danielkurin.circle
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"

packages:
  CircleKit:
    path: CircleKit

targets:
  CircleApp:
    type: application
    platform: macOS
    sources:
      - path: CircleApp
    dependencies:
      - package: CircleKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.danielkurin.circle
        INFOPLIST_FILE: CircleApp/Info.plist
        CODE_SIGN_ENTITLEMENTS: CircleApp/CircleApp.entitlements
        PRODUCT_NAME: Circle
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    entitlements:
      path: CircleApp/CircleApp.entitlements
      properties:
        com.apple.security.app-sandbox: false

  CircleSaver:
    type: bundle
    platform: macOS
    sources:
      - path: CircleSaver
    dependencies:
      - package: CircleKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.danielkurin.circle.saver
        INFOPLIST_FILE: CircleSaver/Info.plist
        PRODUCT_NAME: Circle
        WRAPPER_EXTENSION: saver
        SKIP_INSTALL: true
    info:
      properties:
        NSPrincipalClass: CircleSaver.CircleSaverView
```

**Step 5: Create Info.plist for CircleApp**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Circle</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Daniel Kurin. All rights reserved.</string>
</dict>
</plist>
```

**Step 6: Create entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Step 7: Create CircleSaver Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Circle</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>NSPrincipalClass</key>
    <string>CircleSaver.CircleSaverView</string>
</dict>
</plist>
```

**Step 8: Install XcodeGen and generate project**

```bash
brew install xcodegen  # if not installed
xcodegen generate
```

**Step 9: Verify project builds**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 10: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with CircleKit package, app, and saver targets"
```

---

### Task 2: Settings Manager

**Files:**
- Create: `CircleKit/Sources/CircleKit/SettingsManager.swift`

**Step 1: Write the SettingsManager**

```swift
// CircleKit/Sources/CircleKit/SettingsManager.swift
import Foundation
import Combine

public enum BallSizeMode: String, Codable {
    case pixels
    case percentage
}

public enum ThemeID: String, CaseIterable, Codable {
    case minimal
    case soft
}

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private let defaults: UserDefaults
    public static let suiteName = "com.danielkurin.circle.shared"

    // Notification posted when any setting changes
    public static let settingsChangedNotification = Notification.Name("CircleSettingsChanged")

    // MARK: - Published properties

    @Published public var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "enabled"); notify() }
    }
    @Published public var idleTimeout: Int {
        didSet { defaults.set(idleTimeout, forKey: "idleTimeout"); notify() }
    }
    @Published public var ballSizeMode: BallSizeMode {
        didSet { defaults.set(ballSizeMode.rawValue, forKey: "ballSizeMode"); notify() }
    }
    @Published public var ballSize: Int {
        didSet { defaults.set(ballSize, forKey: "ballSize"); notify() }
    }
    @Published public var ballOpacity: Int {
        didSet { defaults.set(ballOpacity, forKey: "ballOpacity"); notify() }
    }
    @Published public var ballSpeed: Int {
        didSet { defaults.set(ballSpeed, forKey: "ballSpeed"); notify() }
    }
    @Published public var theme: ThemeID {
        didSet { defaults.set(theme.rawValue, forKey: "theme"); notify() }
    }
    @Published public var proximityFadeEnabled: Bool {
        didSet { defaults.set(proximityFadeEnabled, forKey: "proximityFadeEnabled"); notify() }
    }
    @Published public var proximityFadeRadius: Int {
        didSet { defaults.set(proximityFadeRadius, forKey: "proximityFadeRadius"); notify() }
    }
    @Published public var alwaysOnMode: Bool {
        didSet { defaults.set(alwaysOnMode, forKey: "alwaysOnMode"); notify() }
    }
    @Published public var alwaysOnHotkey: String {
        didSet { defaults.set(alwaysOnHotkey, forKey: "alwaysOnHotkey"); notify() }
    }
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin"); notify() }
    }
    @Published public var contentRotationEnabled: Bool {
        didSet { defaults.set(contentRotationEnabled, forKey: "contentRotationEnabled"); notify() }
    }
    @Published public var contentRotationInterval: Int {
        didSet { defaults.set(contentRotationInterval, forKey: "contentRotationInterval"); notify() }
    }
    @Published public var clockEnabled: Bool {
        didSet { defaults.set(clockEnabled, forKey: "clockEnabled"); notify() }
    }
    @Published public var clockFormat24h: Bool {
        didSet { defaults.set(clockFormat24h, forKey: "clockFormat24h"); notify() }
    }
    @Published public var systemInfoEnabled: Bool {
        didSet { defaults.set(systemInfoEnabled, forKey: "systemInfoEnabled"); notify() }
    }
    @Published public var showBattery: Bool {
        didSet { defaults.set(showBattery, forKey: "showBattery"); notify() }
    }

    private init() {
        let defaults = UserDefaults(suiteName: SettingsManager.suiteName) ?? .standard
        self.defaults = defaults

        // Register defaults
        defaults.register(defaults: [
            "enabled": true,
            "idleTimeout": 10,
            "ballSizeMode": "percentage",
            "ballSize": 10,
            "ballOpacity": 100,
            "ballSpeed": 100,
            "theme": "minimal",
            "proximityFadeEnabled": true,
            "proximityFadeRadius": 150,
            "alwaysOnMode": false,
            "alwaysOnHotkey": "cmd+opt+o",
            "launchAtLogin": false,
            "contentRotationEnabled": true,
            "contentRotationInterval": 10,
            "clockEnabled": true,
            "clockFormat24h": false,
            "systemInfoEnabled": true,
            "showBattery": true,
        ])

        // Load values
        self.enabled = defaults.bool(forKey: "enabled")
        self.idleTimeout = defaults.integer(forKey: "idleTimeout")
        self.ballSizeMode = BallSizeMode(rawValue: defaults.string(forKey: "ballSizeMode") ?? "percentage") ?? .percentage
        self.ballSize = defaults.integer(forKey: "ballSize")
        self.ballOpacity = defaults.integer(forKey: "ballOpacity")
        self.ballSpeed = defaults.integer(forKey: "ballSpeed")
        self.theme = ThemeID(rawValue: defaults.string(forKey: "theme") ?? "minimal") ?? .minimal
        self.proximityFadeEnabled = defaults.bool(forKey: "proximityFadeEnabled")
        self.proximityFadeRadius = defaults.integer(forKey: "proximityFadeRadius")
        self.alwaysOnMode = defaults.bool(forKey: "alwaysOnMode")
        self.alwaysOnHotkey = defaults.string(forKey: "alwaysOnHotkey") ?? "cmd+opt+o"
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.contentRotationEnabled = defaults.bool(forKey: "contentRotationEnabled")
        self.contentRotationInterval = defaults.integer(forKey: "contentRotationInterval")
        self.clockEnabled = defaults.bool(forKey: "clockEnabled")
        self.clockFormat24h = defaults.bool(forKey: "clockFormat24h")
        self.systemInfoEnabled = defaults.bool(forKey: "systemInfoEnabled")
        self.showBattery = defaults.bool(forKey: "showBattery")
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.settingsChangedNotification, object: self)
    }
}
```

**Step 2: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CircleKit/Sources/CircleKit/SettingsManager.swift
git commit -m "feat: add SettingsManager with UserDefaults persistence"
```

---

### Task 3: Ball Physics

**Files:**
- Create: `CircleKit/Sources/CircleKit/BallPhysics.swift`
- Create: `CircleKit/Tests/CircleKitTests/BallPhysicsTests.swift`

**Step 1: Write the failing test**

```swift
// CircleKit/Tests/CircleKitTests/BallPhysicsTests.swift
import XCTest
@testable import CircleKit

final class BallPhysicsTests: XCTestCase {

    func testInitialPosition() {
        let ball = BallState(
            screenWidth: 1920,
            screenHeight: 1080,
            sizeMode: .percentage,
            sizeValue: 10,
            speedPercentage: 100
        )
        XCTAssertEqual(ball.x, 960, accuracy: 1)
        XCTAssertEqual(ball.y, 540, accuracy: 1)
    }

    func testRadiusPercentageMode() {
        let ball = BallState(
            screenWidth: 1920,
            screenHeight: 1080,
            sizeMode: .percentage,
            sizeValue: 10,
            speedPercentage: 100
        )
        // 10% of min(1920, 1080) = 108
        XCTAssertEqual(ball.radius, 108, accuracy: 1)
    }

    func testRadiusPixelMode() {
        let ball = BallState(
            screenWidth: 1920,
            screenHeight: 1080,
            sizeMode: .pixels,
            sizeValue: 50,
            speedPercentage: 100
        )
        XCTAssertEqual(ball.radius, 50, accuracy: 1)
    }

    func testBounceChangesDirection() {
        var ball = BallState(
            screenWidth: 100,
            screenHeight: 100,
            sizeMode: .pixels,
            sizeValue: 10,
            speedPercentage: 100
        )
        // Place ball at right edge moving right
        ball.x = 100
        ball.vx = 4
        ball.vy = 3

        // Force a bounce (not wrap) by seeding
        let oldHue = ball.hue
        BallPhysics.update(&ball, bounds: CGSize(width: 100, height: 100), forceAction: .bounce)

        // After bounce, vx should be negative (reversed)
        XCTAssertLessThan(ball.vx, 0)
        // Hue should shift
        XCTAssertNotEqual(ball.hue, oldHue)
    }

    func testProximityOpacityFullWhenFar() {
        let ball = BallState(
            screenWidth: 1000,
            screenHeight: 1000,
            sizeMode: .pixels,
            sizeValue: 50,
            speedPercentage: 100
        )
        // Cursor very far away
        let opacity = BallPhysics.proximityOpacity(
            ball: ball,
            cursorPosition: CGPoint(x: -1000, y: -1000),
            fadeRadius: 150,
            fadeEnabled: true
        )
        XCTAssertEqual(opacity, 1.0, accuracy: 0.01)
    }

    func testProximityOpacityZeroWhenInside() {
        var ball = BallState(
            screenWidth: 1000,
            screenHeight: 1000,
            sizeMode: .pixels,
            sizeValue: 50,
            speedPercentage: 100
        )
        ball.x = 500
        ball.y = 500
        // Cursor at ball center
        let opacity = BallPhysics.proximityOpacity(
            ball: ball,
            cursorPosition: CGPoint(x: 500, y: 500),
            fadeRadius: 150,
            fadeEnabled: true
        )
        XCTAssertEqual(opacity, 0.0, accuracy: 0.01)
    }

    func testProximityOpacityDisabled() {
        var ball = BallState(
            screenWidth: 1000,
            screenHeight: 1000,
            sizeMode: .pixels,
            sizeValue: 50,
            speedPercentage: 100
        )
        ball.x = 500
        ball.y = 500
        let opacity = BallPhysics.proximityOpacity(
            ball: ball,
            cursorPosition: CGPoint(x: 500, y: 500),
            fadeRadius: 150,
            fadeEnabled: false
        )
        XCTAssertEqual(opacity, 1.0, accuracy: 0.01)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" 2>&1 | tail -10
```

Expected: FAIL - types not found

**Step 3: Write BallPhysics implementation**

```swift
// CircleKit/Sources/CircleKit/BallPhysics.swift
import Foundation
import CoreGraphics

public struct BallState {
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var radius: CGFloat
    public var hue: CGFloat
    public var maxSpeed: CGFloat
    public var speedMultiplier: CGFloat

    public init(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        sizeMode: BallSizeMode,
        sizeValue: Int,
        speedPercentage: Int
    ) {
        self.speedMultiplier = CGFloat(speedPercentage) / 100.0
        self.x = screenWidth / 2
        self.y = screenHeight / 2
        self.vx = 4 * speedMultiplier
        self.vy = 3 * speedMultiplier
        self.maxSpeed = 8 * speedMultiplier
        self.hue = CGFloat.random(in: 0...360)

        if sizeMode == .pixels {
            self.radius = CGFloat(sizeValue)
        } else {
            let minDim = min(screenWidth, screenHeight)
            self.radius = minDim * CGFloat(sizeValue) / 100.0
        }
    }

    public mutating func updateRadius(screenWidth: CGFloat, screenHeight: CGFloat, sizeMode: BallSizeMode, sizeValue: Int) {
        if sizeMode == .pixels {
            self.radius = CGFloat(sizeValue)
        } else {
            let minDim = min(screenWidth, screenHeight)
            self.radius = minDim * CGFloat(sizeValue) / 100.0
        }
    }

    public mutating func updateSpeed(percentage: Int) {
        self.speedMultiplier = CGFloat(percentage) / 100.0
        self.maxSpeed = 8 * speedMultiplier
    }
}

public enum EdgeAction {
    case bounce
    case wrap
}

public enum BallPhysics {

    /// Default update using theme-independent legacy bounce/wrap logic.
    /// Use this only as fallback when no theme provides updateMotion.
    public static func update(_ ball: inout BallState, bounds: CGSize, forceAction: EdgeAction? = nil) {
        ball.x += ball.vx
        ball.y += ball.vy

        let wrapChance: CGFloat = 0.3

        // Horizontal edges
        if ball.x <= 0 || ball.x >= bounds.width {
            let action = forceAction ?? (CGFloat.random(in: 0...1) < wrapChance ? .wrap : .bounce)
            if action == .wrap {
                ball.x = ball.x <= 0 ? bounds.width : 0
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            } else {
                ball.vx = -ball.vx
                ball.x = ball.x <= 0 ? 0 : bounds.width
                if CGFloat.random(in: 0...1) < 0.2 {
                    ball.vy = (CGFloat.random(in: 0...1) - 0.5) * ball.maxSpeed * 1.5
                } else {
                    ball.vy += (CGFloat.random(in: 0...1) - 0.5) * 6
                }
                limitSpeed(&ball)
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            }
        }

        // Vertical edges
        if ball.y <= 0 || ball.y >= bounds.height {
            let action = forceAction ?? (CGFloat.random(in: 0...1) < wrapChance ? .wrap : .bounce)
            if action == .wrap {
                ball.y = ball.y <= 0 ? bounds.height : 0
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            } else {
                ball.vy = -ball.vy
                ball.y = ball.y <= 0 ? 0 : bounds.height
                if CGFloat.random(in: 0...1) < 0.2 {
                    ball.vx = (CGFloat.random(in: 0...1) - 0.5) * ball.maxSpeed * 1.5
                } else {
                    ball.vx += (CGFloat.random(in: 0...1) - 0.5) * 6
                }
                limitSpeed(&ball)
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            }
        }
    }

    public static func limitSpeed(_ ball: inout BallState) {
        let currentSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        if currentSpeed > ball.maxSpeed {
            let scale = ball.maxSpeed / currentSpeed
            ball.vx *= scale
            ball.vy *= scale
        }
    }

    /// Calculate opacity based on cursor proximity.
    /// Returns 1.0 when far, 0.0 when cursor is inside circle, quadratic fade in between.
    public static func proximityOpacity(
        ball: BallState,
        cursorPosition: CGPoint,
        fadeRadius: CGFloat,
        fadeEnabled: Bool
    ) -> CGFloat {
        guard fadeEnabled else { return 1.0 }

        let dx = ball.x - cursorPosition.x
        let dy = ball.y - cursorPosition.y
        let distFromCenter = sqrt(dx * dx + dy * dy)
        let distFromEdge = distFromCenter - ball.radius

        if distFromEdge >= fadeRadius { return 1.0 }
        if distFromEdge <= 0 { return 0.0 }

        let linear = distFromEdge / fadeRadius
        return linear * linear  // Quadratic fade
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" 2>&1 | tail -10
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add CircleKit/Sources/CircleKit/BallPhysics.swift CircleKit/Tests/CircleKitTests/BallPhysicsTests.swift
git commit -m "feat: add BallPhysics with bounce/wrap logic and proximity fade"
```

---

### Task 4: Theme Protocol and Minimal Theme

**Files:**
- Create: `CircleKit/Sources/CircleKit/Themes/ThemeProtocol.swift`
- Create: `CircleKit/Sources/CircleKit/Themes/MinimalTheme.swift`

**Step 1: Write ThemeProtocol**

```swift
// CircleKit/Sources/CircleKit/Themes/ThemeProtocol.swift
import Foundation
import QuartzCore
import AppKit

public struct ContentData {
    public let icon: String
    public let text: String

    public init(icon: String, text: String) {
        self.icon = icon
        self.text = text
    }
}

public struct MotionState {
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var radius: CGFloat
    public var hue: CGFloat
    public var speedMultiplier: CGFloat

    public init(from ball: BallState) {
        self.x = ball.x
        self.y = ball.y
        self.vx = ball.vx
        self.vy = ball.vy
        self.radius = ball.radius
        self.hue = ball.hue
        self.speedMultiplier = ball.speedMultiplier
    }
}

public protocol Theme: AnyObject {
    static var themeName: String { get }
    static var themeId: ThemeID { get }

    /// Set up sublayers in the given parent layer
    func setup(in parentLayer: CALayer)

    /// Called each frame to update internal time tracking
    func tick(deltaTime: CFTimeInterval)

    /// Update ball motion — returns new motion state. Each theme can have custom physics.
    func updateMotion(state: MotionState, bounds: CGSize) -> MotionState

    /// Update visual appearance for current frame
    func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat)

    /// Update displayed content text
    func setContent(_ content: ContentData?)

    /// Remove all sublayers
    func teardown()
}
```

**Step 2: Write MinimalTheme**

```swift
// CircleKit/Sources/CircleKit/Themes/MinimalTheme.swift
import Foundation
import QuartzCore
import AppKit

public final class MinimalTheme: Theme {
    public static let themeName = "Minimal"
    public static let themeId = ThemeID.minimal

    private var circleLayer = CALayer()
    private var glowLayer = CALayer()
    private var iconLayer = CATextLayer()
    private var textLayer = CATextLayer()
    private var time: CFTimeInterval = 0
    private var angle: CGFloat = CGFloat.random(in: 0...(2 * .pi))

    public init() {}

    public func setup(in parentLayer: CALayer) {
        // Glow layer (behind circle)
        glowLayer.shadowColor = NSColor.white.cgColor
        glowLayer.shadowOpacity = 0.3
        glowLayer.shadowRadius = 20
        glowLayer.shadowOffset = .zero
        parentLayer.addSublayer(glowLayer)

        // Main circle
        circleLayer.masksToBounds = true
        parentLayer.addSublayer(circleLayer)

        // Icon text layer
        iconLayer.alignmentMode = .center
        iconLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        iconLayer.isWrapped = false
        iconLayer.truncationMode = .none
        circleLayer.addSublayer(iconLayer)

        // Text layer
        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.isWrapped = true
        textLayer.truncationMode = .none
        circleLayer.addSublayer(textLayer)
    }

    public func tick(deltaTime: CFTimeInterval) {
        time += deltaTime
    }

    public func updateMotion(state: MotionState, bounds: CGSize) -> MotionState {
        var s = state
        let baseSpeed: CGFloat = 3
        let speed = baseSpeed * s.speedMultiplier

        // Smooth drift — gradual angle changes
        angle += CGFloat.random(in: -0.01...0.01)

        s.vx = cos(angle) * speed
        s.vy = sin(angle) * speed
        s.x += s.vx
        s.y += s.vy

        // Continuous slow hue shift
        s.hue = (s.hue + 0.1).truncatingRemainder(dividingBy: 360)

        // Bounce when center hits edge
        if s.x < 0 {
            angle = .pi - angle + CGFloat.random(in: -0.25...0.25)
            s.x = 0
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        } else if s.x > bounds.width {
            angle = .pi - angle + CGFloat.random(in: -0.25...0.25)
            s.x = bounds.width
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        if s.y < 0 {
            angle = -angle + CGFloat.random(in: -0.25...0.25)
            s.y = 0
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        } else if s.y > bounds.height {
            angle = -angle + CGFloat.random(in: -0.25...0.25)
            s.y = bounds.height
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        return s
    }

    public func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Gentle hue oscillation
        let shift = sin(time / 10.0) * 5
        let h = ((hue + shift).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360.0
        let color = NSColor(hue: h, saturation: 0.3, brightness: 0.6, alpha: opacity)

        let frame = CGRect(
            x: position.x - size,
            y: position.y - size,
            width: size * 2,
            height: size * 2
        )

        // Circle
        circleLayer.frame = frame
        circleLayer.cornerRadius = size
        circleLayer.backgroundColor = color.cgColor

        // Glow
        let glowSize = size * 1.3
        glowLayer.frame = CGRect(
            x: position.x - glowSize,
            y: position.y - glowSize,
            width: glowSize * 2,
            height: glowSize * 2
        )
        glowLayer.cornerRadius = glowSize
        glowLayer.backgroundColor = color.withAlphaComponent(opacity * 0.15).cgColor
        glowLayer.shadowColor = color.cgColor
        glowLayer.shadowOpacity = Float(opacity * 0.3)
        glowLayer.shadowRadius = size * 0.3

        // Layout text layers relative to circle bounds
        let iconSize = size * 0.25
        let textSize = size * 0.15

        iconLayer.fontSize = iconSize
        iconLayer.frame = CGRect(
            x: 0,
            y: size * 0.4,  // Upper portion (CA coordinates: origin bottom-left)
            width: size * 2,
            height: iconSize * 1.4
        )

        textLayer.fontSize = textSize
        textLayer.frame = CGRect(
            x: 0,
            y: size * 0.05,
            width: size * 2,
            height: size * 0.9
        )

        CATransaction.commit()
    }

    public func setContent(_ content: ContentData?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let content {
            iconLayer.string = content.icon
            iconLayer.foregroundColor = NSColor.white.cgColor

            let attributed = NSMutableAttributedString(string: content.text)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 2
            attributed.addAttributes([
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: textLayer.fontSize),
                .paragraphStyle: paragraphStyle
            ], range: NSRange(location: 0, length: attributed.length))
            textLayer.string = attributed
        } else {
            iconLayer.string = nil
            textLayer.string = nil
        }

        CATransaction.commit()
    }

    public func teardown() {
        glowLayer.removeFromSuperlayer()
        circleLayer.removeFromSuperlayer()
    }
}
```

**Step 3: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CircleKit/Sources/CircleKit/Themes/
git commit -m "feat: add Theme protocol and MinimalTheme with Core Animation"
```

---

### Task 5: Soft Theme

**Files:**
- Create: `CircleKit/Sources/CircleKit/Themes/SoftTheme.swift`

**Step 1: Write SoftTheme**

```swift
// CircleKit/Sources/CircleKit/Themes/SoftTheme.swift
import Foundation
import QuartzCore
import AppKit

public final class SoftTheme: Theme {
    public static let themeName = "Soft"
    public static let themeId = ThemeID.soft

    private var blobLayer = CAShapeLayer()
    private var iconLayer = CATextLayer()
    private var textLayer = CATextLayer()
    private var time: CFTimeInterval = 0
    private var morphPhase: CGFloat = CGFloat.random(in: 0...(2 * .pi))
    private var squish: CGFloat = 1
    private var squishTarget: CGFloat = 1

    // Pastel palette
    private let palette: [(h: CGFloat, s: CGFloat, l: CGFloat)] = [
        (270, 0.40, 0.75),  // Lavender
        (15,  0.45, 0.80),  // Soft coral
        (150, 0.35, 0.75),  // Mint
        (45,  0.40, 0.80),  // Pale gold
        (200, 0.40, 0.78),  // Sky blue
    ]
    private var colorIndex = 0
    private var colorTransition: CGFloat = 0

    public init() {}

    public func setup(in parentLayer: CALayer) {
        blobLayer.fillColor = NSColor.white.cgColor
        blobLayer.strokeColor = nil
        parentLayer.addSublayer(blobLayer)

        iconLayer.alignmentMode = .center
        iconLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        iconLayer.isWrapped = false
        iconLayer.truncationMode = .none
        blobLayer.addSublayer(iconLayer)

        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.isWrapped = true
        textLayer.truncationMode = .none
        blobLayer.addSublayer(textLayer)
    }

    public func tick(deltaTime: CFTimeInterval) {
        time += deltaTime
        morphPhase += 0.02
    }

    private func currentColor(opacity: CGFloat) -> NSColor {
        colorTransition += 0.0002
        if colorTransition >= 1 {
            colorTransition = 0
            colorIndex = (colorIndex + 1) % palette.count
        }

        let current = palette[colorIndex]
        let next = palette[(colorIndex + 1) % palette.count]
        let t = colorTransition

        let h = (current.h + (next.h - current.h) * t) / 360.0
        let s = current.s + (next.s - current.s) * t
        let b = current.l + (next.l - current.l) * t

        return NSColor(hue: h, saturation: s, brightness: b, alpha: opacity)
    }

    public func updateMotion(state: MotionState, bounds: CGSize) -> MotionState {
        var s = state
        let baseSpeed: CGFloat = 3
        let speed = baseSpeed * s.speedMultiplier

        // Add slight momentum variation
        s.vx += CGFloat.random(in: -0.05...0.05)
        s.vy += CGFloat.random(in: -0.05...0.05)

        // Limit speed
        let currentSpeed = sqrt(s.vx * s.vx + s.vy * s.vy)
        if currentSpeed > speed {
            s.vx = (s.vx / currentSpeed) * speed
            s.vy = (s.vy / currentSpeed) * speed
        }
        if currentSpeed < speed * 0.5 {
            s.vx = (s.vx / currentSpeed) * speed * 0.5
            s.vy = (s.vy / currentSpeed) * speed * 0.5
        }

        s.x += s.vx
        s.y += s.vy

        // Bounce from center point
        if s.x < 0 || s.x > bounds.width {
            s.vx = -s.vx
            s.vy += CGFloat.random(in: -0.25...0.25)
            squishTarget = 0.7
            s.x = max(0, min(bounds.width, s.x))
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        if s.y < 0 || s.y > bounds.height {
            s.vy = -s.vy
            s.vx += CGFloat.random(in: -0.25...0.25)
            squishTarget = 0.7
            s.y = max(0, min(bounds.height, s.y))
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        // Recover from squish
        squish += (squishTarget - squish) * 0.1
        squishTarget += (1 - squishTarget) * 0.05

        return s
    }

    public func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let color = currentColor(opacity: opacity)

        // Build blob path
        let path = CGMutablePath()
        let points = 6
        var firstPoint: CGPoint?

        for i in 0...points {
            let angle = CGFloat(i) / CGFloat(points) * 2 * .pi
            let morphAmount = sin(morphPhase + angle * 2) * 0.08
            let squishX = i % 2 == 0 ? squish : 1
            let squishY = i % 2 == 0 ? 1 : squish
            let r = size * (1 + morphAmount) * ((squishX + squishY) / 2)

            let px = position.x + cos(angle) * r * squishX
            let py = position.y + sin(angle) * r * squishY

            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
                firstPoint = CGPoint(x: px, y: py)
            } else {
                let prevAngle = CGFloat(i - 1) / CGFloat(points) * 2 * .pi
                let cpRadius = r * 0.55
                let cp1 = CGPoint(
                    x: position.x + cos(prevAngle + .pi / CGFloat(points)) * cpRadius,
                    y: position.y + sin(prevAngle + .pi / CGFloat(points)) * cpRadius
                )
                let cp2 = CGPoint(
                    x: position.x + cos(angle - .pi / CGFloat(points)) * cpRadius,
                    y: position.y + sin(angle - .pi / CGFloat(points)) * cpRadius
                )
                path.addCurve(to: CGPoint(x: px, y: py), control1: cp1, control2: cp2)
            }
        }
        path.closeSubpath()

        blobLayer.path = path
        blobLayer.fillColor = color.cgColor

        // Position text layers relative to blob bounds
        let blobBounds = path.boundingBox
        blobLayer.frame = blobBounds

        // Recalculate path in local coordinates
        let localPath = CGMutablePath()
        var localFirstPoint: CGPoint?
        for i in 0...points {
            let angle = CGFloat(i) / CGFloat(points) * 2 * .pi
            let morphAmount = sin(morphPhase + angle * 2) * 0.08
            let squishX = i % 2 == 0 ? squish : 1
            let squishY = i % 2 == 0 ? 1 : squish
            let r = size * (1 + morphAmount) * ((squishX + squishY) / 2)

            let cx = position.x - blobBounds.origin.x
            let cy = position.y - blobBounds.origin.y
            let px = cx + cos(angle) * r * squishX
            let py = cy + sin(angle) * r * squishY

            if i == 0 {
                localPath.move(to: CGPoint(x: px, y: py))
                localFirstPoint = CGPoint(x: px, y: py)
            } else {
                let prevAngle = CGFloat(i - 1) / CGFloat(points) * 2 * .pi
                let cpRadius = r * 0.55
                let cp1 = CGPoint(
                    x: cx + cos(prevAngle + .pi / CGFloat(points)) * cpRadius,
                    y: cy + sin(prevAngle + .pi / CGFloat(points)) * cpRadius
                )
                let cp2 = CGPoint(
                    x: cx + cos(angle - .pi / CGFloat(points)) * cpRadius,
                    y: cy + sin(angle - .pi / CGFloat(points)) * cpRadius
                )
                localPath.addCurve(to: CGPoint(x: px, y: py), control1: cp1, control2: cp2)
            }
        }
        localPath.closeSubpath()
        blobLayer.path = localPath

        // Text positioning
        let localCenterX = position.x - blobBounds.origin.x
        let localCenterY = position.y - blobBounds.origin.y
        let iconSize = size * 0.25
        let textSize = size * 0.15

        iconLayer.fontSize = iconSize
        iconLayer.frame = CGRect(
            x: localCenterX - size,
            y: localCenterY - size * 0.1,
            width: size * 2,
            height: iconSize * 1.4
        )

        textLayer.fontSize = textSize
        textLayer.frame = CGRect(
            x: localCenterX - size,
            y: localCenterY - size * 0.6,
            width: size * 2,
            height: size * 0.9
        )

        CATransaction.commit()
    }

    public func setContent(_ content: ContentData?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let content {
            iconLayer.string = content.icon
            iconLayer.foregroundColor = NSColor.white.cgColor

            let attributed = NSMutableAttributedString(string: content.text)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 2
            attributed.addAttributes([
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: textLayer.fontSize),
                .paragraphStyle: paragraphStyle
            ], range: NSRange(location: 0, length: attributed.length))
            textLayer.string = attributed
        } else {
            iconLayer.string = nil
            textLayer.string = nil
        }

        CATransaction.commit()
    }

    public func teardown() {
        blobLayer.removeFromSuperlayer()
    }
}
```

**Step 2: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CircleKit/Sources/CircleKit/Themes/SoftTheme.swift
git commit -m "feat: add SoftTheme with morphing blob and pastel palette"
```

---

### Task 6: Content Providers

**Files:**
- Create: `CircleKit/Sources/CircleKit/Providers/ContentProvider.swift`
- Create: `CircleKit/Sources/CircleKit/Providers/ClockProvider.swift`
- Create: `CircleKit/Sources/CircleKit/Providers/SystemInfoProvider.swift`

**Step 1: Write ContentProvider protocol**

```swift
// CircleKit/Sources/CircleKit/Providers/ContentProvider.swift
import Foundation

public protocol ContentProvider: AnyObject {
    var refreshInterval: TimeInterval { get }
    var cachedData: ContentData? { get }

    func fetchData() async
    func start()
    func stop()
}

public class BaseContentProvider: ContentProvider {
    public var cachedData: ContentData?
    public var refreshInterval: TimeInterval { 1.0 }

    private var timer: Timer?
    private var isFetching = false

    public init() {}

    public func fetchData() async {
        // Override in subclass
    }

    public func start() {
        // Initial fetch
        Task { await fetchData() }

        // Setup timer on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self, !self.isFetching else { return }
            self.isFetching = true
            Task {
                await self.fetchData()
                self.isFetching = false
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        cachedData = nil
    }
}
```

**Step 2: Write ClockProvider**

```swift
// CircleKit/Sources/CircleKit/Providers/ClockProvider.swift
import Foundation

public final class ClockProvider: BaseContentProvider {
    private let use24Hour: Bool

    public override var refreshInterval: TimeInterval { 1.0 }

    public init(use24Hour: Bool = false) {
        self.use24Hour = use24Hour
        super.init()
    }

    public override func fetchData() async {
        let now = Date()

        let timeFormatter = DateFormatter()
        if use24Hour {
            timeFormatter.dateFormat = "HH:mm"
        } else {
            timeFormatter.dateFormat = "h:mm a"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let time = timeFormatter.string(from: now)
        let date = dateFormatter.string(from: now)

        cachedData = ContentData(
            icon: "\u{1F550}",  // 🕐
            text: "\(time)\n\(date)"
        )
    }
}
```

**Step 3: Write SystemInfoProvider**

```swift
// CircleKit/Sources/CircleKit/Providers/SystemInfoProvider.swift
import Foundation
import IOKit.ps

public final class SystemInfoProvider: BaseContentProvider {
    private let showBattery: Bool

    public override var refreshInterval: TimeInterval { 2.0 }

    public init(showBattery: Bool = true) {
        self.showBattery = showBattery
        super.init()
    }

    public override func fetchData() async {
        let cpu = Self.cpuUsage()
        let mem = Self.memoryUsage()

        var text = "\u{2699}\u{FE0F} \(cpu)%  \u{1F4BE} \(mem.used)/\(mem.total) GB"

        if showBattery, let battery = Self.batteryLevel() {
            text += "\n\u{1F50B} \(battery)%"
        }

        cachedData = ContentData(
            icon: "\u{1F4CA}",  // 📊
            text: text
        )
    }

    // MARK: - System Info Helpers

    private static func cpuUsage() -> Int {
        var totalLoad: Int32 = 0
        var totalTicks: Int32 = 0

        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = cpuInfo[offset + Int(CPU_STATE_USER)]
            let system = cpuInfo[offset + Int(CPU_STATE_SYSTEM)]
            let idle = cpuInfo[offset + Int(CPU_STATE_IDLE)]
            let nice = cpuInfo[offset + Int(CPU_STATE_NICE)]

            let used = user + system + nice
            let total = used + idle
            totalLoad += used
            totalTicks += total
        }

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)

        guard totalTicks > 0 else { return 0 }
        return Int((Double(totalLoad) / Double(totalTicks)) * 100)
    }

    private static func memoryUsage() -> (used: String, total: String) {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalBytes) / 1_073_741_824

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (String(format: "%.1f", 0), String(format: "%.0f", totalGB))
        }

        let pageSize = vm_kernel_page_size
        let activeBytes = UInt64(stats.active_count) * UInt64(pageSize)
        let wiredBytes = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressedBytes = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let usedBytes = activeBytes + wiredBytes + compressedBytes
        let usedGB = Double(usedBytes) / 1_073_741_824

        return (String(format: "%.1f", usedGB), String(format: "%.0f", totalGB))
    }

    private static func batteryLevel() -> Int? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
              let capacity = info[kIOPSCurrentCapacityKey] as? Int else {
            return nil
        }
        return capacity
    }
}
```

**Step 4: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CircleKit/Sources/CircleKit/Providers/
git commit -m "feat: add content providers — Clock and SystemInfo"
```

---

### Task 7: Content Rotator

**Files:**
- Create: `CircleKit/Sources/CircleKit/Providers/ContentRotator.swift`
- Create: `CircleKit/Tests/CircleKitTests/ContentRotatorTests.swift`

**Step 1: Write failing test**

```swift
// CircleKit/Tests/CircleKitTests/ContentRotatorTests.swift
import XCTest
@testable import CircleKit

final class ContentRotatorTests: XCTestCase {

    func testRotatesProviders() {
        let clock = ClockProvider()
        let system = SystemInfoProvider()
        let rotator = ContentRotator(providers: [clock, system], intervalSeconds: 10)

        XCTAssertTrue(rotator.currentProvider === clock)
        rotator.next()
        XCTAssertTrue(rotator.currentProvider === system)
        rotator.next()
        XCTAssertTrue(rotator.currentProvider === clock)  // Wraps around
    }

    func testEmptyProviders() {
        let rotator = ContentRotator(providers: [], intervalSeconds: 10)
        XCTAssertNil(rotator.currentProvider)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
xcodebuild test -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" 2>&1 | tail -10
```

Expected: FAIL

**Step 3: Write ContentRotator**

```swift
// CircleKit/Sources/CircleKit/Providers/ContentRotator.swift
import Foundation

public final class ContentRotator {
    private var providers: [ContentProvider]
    private var currentIndex = 0
    private var rotationTimer: Timer?
    private let intervalSeconds: Int

    public var currentProvider: ContentProvider? {
        guard !providers.isEmpty else { return nil }
        return providers[currentIndex]
    }

    public init(providers: [ContentProvider], intervalSeconds: Int) {
        self.providers = providers
        self.intervalSeconds = intervalSeconds
    }

    public func next() {
        guard !providers.isEmpty else { return }
        currentIndex = (currentIndex + 1) % providers.count
    }

    public func start() {
        providers.forEach { $0.start() }

        if providers.count > 1 {
            rotationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { [weak self] _ in
                self?.next()
            }
        }
    }

    public func stop() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        providers.forEach { $0.stop() }
    }
}
```

**Step 4: Run tests**

```bash
xcodebuild test -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" 2>&1 | tail -10
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add CircleKit/Sources/CircleKit/Providers/ContentRotator.swift CircleKit/Tests/CircleKitTests/ContentRotatorTests.swift
git commit -m "feat: add ContentRotator for cycling between providers"
```

---

### Task 8: CircleRenderer (Main Animation Driver)

**Files:**
- Create: `CircleKit/Sources/CircleKit/CircleRenderer.swift`

**Step 1: Write CircleRenderer**

This is the central class that both the menu bar app and screen saver will use.

```swift
// CircleKit/Sources/CircleKit/CircleRenderer.swift
import Foundation
import QuartzCore
import AppKit

public final class CircleRenderer {
    private var ball: BallState
    private var theme: Theme
    private var contentRotator: ContentRotator?
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private let hostLayer: CALayer
    private let bounds: CGSize
    private let settings: SettingsManager

    // Proximity fade state (set from outside)
    public var cursorPosition: CGPoint = CGPoint(x: -1000, y: -1000)

    public init(hostLayer: CALayer, bounds: CGSize) {
        self.hostLayer = hostLayer
        self.bounds = bounds
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
        lastFrameTime = CACurrentMediaTime()

        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let renderer = Unmanaged<CircleRenderer>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                renderer.frame()
            }
            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, pointer)
        CVDisplayLinkStart(displayLink)
        self.displayLink = displayLink
    }

    public func stop() {
        if let displayLink {
            CVDisplayLinkStop(displayLink)
        }
        displayLink = nil
        contentRotator?.stop()
        theme.teardown()
    }

    private func frame() {
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

        // Theme change
        if Self.createTheme(for: settings.theme) is MinimalTheme != theme is MinimalTheme {
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
```

**Step 2: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CircleKit/Sources/CircleKit/CircleRenderer.swift
git commit -m "feat: add CircleRenderer with CVDisplayLink animation loop"
```

---

### Task 9: Menu Bar App — App Delegate and Tray

**Files:**
- Create: `CircleApp/AppDelegate.swift`
- Create: `CircleApp/TrayManager.swift`

**Step 1: Write AppDelegate**

```swift
// CircleApp/AppDelegate.swift
import AppKit
import CircleKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var trayManager: TrayManager!
    private var overlayController: OverlayWindowController?
    private var idleMonitor: IdleMonitor!
    private var hotkeyManager: HotkeyManager!
    private let settings = SettingsManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple instances
        let runningApps = NSWorkspace.shared.runningApplications
        let isAlreadyRunning = runningApps.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }.count > 0

        if isAlreadyRunning {
            NSApp.terminate(nil)
            return
        }

        // Setup tray
        trayManager = TrayManager(
            onSettingsClick: { [weak self] in self?.showSettings() },
            onAlwaysOnToggle: { [weak self] in self?.toggleAlwaysOn() },
            onQuitClick: { NSApp.terminate(nil) }
        )

        // Setup idle monitor
        idleMonitor = IdleMonitor()
        idleMonitor.onIdle = { [weak self] in
            self?.showOverlays()
        }
        idleMonitor.onActive = { [weak self] in
            self?.dismissOverlays()
        }
        idleMonitor.start()

        // Setup hotkey
        hotkeyManager = HotkeyManager()
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleAlwaysOn()
        }
        hotkeyManager.register()

        // Restore always-on state
        if settings.alwaysOnMode {
            idleMonitor.stop()
            showOverlays()
        }

        // Listen for display changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        cleanup()
        return .terminateNow
    }

    // MARK: - Overlay Management

    private func showOverlays() {
        guard overlayController == nil else { return }
        overlayController = OverlayWindowController()
        overlayController?.show()
    }

    private func dismissOverlays() {
        overlayController?.dismiss()
        overlayController = nil
    }

    // MARK: - Always On

    private func toggleAlwaysOn() {
        settings.alwaysOnMode.toggle()
        trayManager.updateMenu()

        if settings.alwaysOnMode {
            idleMonitor.stop()
            showOverlays()
        } else {
            dismissOverlays()
            idleMonitor.start()
        }
    }

    // MARK: - Settings

    private var settingsWindowController: NSWindowController?

    private func showSettings() {
        if let existing = settingsWindowController {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = SettingsWindowController()
        window.showWindow(nil)
        settingsWindowController = window
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Display Changes

    @objc private func displaysChanged() {
        guard settings.alwaysOnMode, overlayController != nil else { return }
        dismissOverlays()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.settings.alwaysOnMode else { return }
            self.showOverlays()
        }
    }

    private func cleanup() {
        hotkeyManager.unregister()
        idleMonitor.stop()
        dismissOverlays()
    }
}
```

**Step 2: Write TrayManager**

```swift
// CircleApp/TrayManager.swift
import AppKit
import CircleKit

final class TrayManager {
    private var statusItem: NSStatusItem!
    private let onSettingsClick: () -> Void
    private let onAlwaysOnToggle: () -> Void
    private let onQuitClick: () -> Void

    init(
        onSettingsClick: @escaping () -> Void,
        onAlwaysOnToggle: @escaping () -> Void,
        onQuitClick: @escaping () -> Void
    ) {
        self.onSettingsClick = onSettingsClick
        self.onAlwaysOnToggle = onAlwaysOnToggle
        self.onQuitClick = onQuitClick

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Circle")
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    func updateMenu() {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let settings = SettingsManager.shared

        // Enable/Disable
        let enableItem = NSMenuItem(
            title: settings.enabled ? "Disable" : "Enable",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enableItem.target = self
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // Always On
        let alwaysOnItem = NSMenuItem(
            title: "Always On",
            action: #selector(alwaysOnClicked),
            keyEquivalent: ""
        )
        alwaysOnItem.target = self
        alwaysOnItem.state = settings.alwaysOnMode ? .on : .off
        menu.addItem(alwaysOnItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Circle",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        SettingsManager.shared.enabled.toggle()
        buildMenu()
    }

    @objc private func alwaysOnClicked() {
        onAlwaysOnToggle()
    }

    @objc private func settingsClicked() {
        onSettingsClick()
    }

    @objc private func quitClicked() {
        onQuitClick()
    }
}
```

**Step 3: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED (may need stub files for OverlayWindowController, IdleMonitor, HotkeyManager, SettingsWindowController — create empty stubs if needed)

**Step 4: Commit**

```bash
git add CircleApp/AppDelegate.swift CircleApp/TrayManager.swift
git commit -m "feat: add AppDelegate with tray manager and app lifecycle"
```

---

### Task 10: Idle Monitor

**Files:**
- Create: `CircleApp/IdleMonitor.swift`

**Step 1: Write IdleMonitor**

```swift
// CircleApp/IdleMonitor.swift
import Foundation
import CoreGraphics
import CircleKit

final class IdleMonitor {
    var onIdle: (() -> Void)?
    var onActive: (() -> Void)?

    private var timer: Timer?
    private var isScreensaverActive = false
    private let pollInterval: TimeInterval = 1.0

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkIdleState() {
        let settings = SettingsManager.shared
        guard settings.enabled else { return }

        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let mouseClickIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)

        // Use the minimum idle time across all input types
        let minIdle = min(idleSeconds, min(keyboardIdle, mouseClickIdle))
        let threshold = TimeInterval(settings.idleTimeout)

        if !isScreensaverActive {
            if minIdle >= threshold {
                isScreensaverActive = true
                onIdle?()
            }
        } else {
            // Check if user became active (idle time dropped below 2 seconds)
            if minIdle < 2 && !settings.alwaysOnMode {
                isScreensaverActive = false
                onActive?()
            }
        }
    }
}
```

**Step 2: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CircleApp/IdleMonitor.swift
git commit -m "feat: add IdleMonitor using CGEventSource"
```

---

### Task 11: Overlay Window Controller

**Files:**
- Create: `CircleApp/OverlayWindowController.swift`
- Create: `CircleApp/CircleOverlayView.swift`

**Step 1: Write OverlayWindowController**

```swift
// CircleApp/OverlayWindowController.swift
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
```

**Step 2: Write CircleOverlayView**

```swift
// CircleApp/CircleOverlayView.swift
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
            // Convert screen coordinates to view coordinates
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
```

**Step 3: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CircleApp/OverlayWindowController.swift CircleApp/CircleOverlayView.swift
git commit -m "feat: add overlay windows with transparent click-through rendering"
```

---

### Task 12: Hotkey Manager

**Files:**
- Create: `CircleApp/HotkeyManager.swift`

**Step 1: Write HotkeyManager**

```swift
// CircleApp/HotkeyManager.swift
import Foundation
import Carbon
import CircleKit

final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register() {
        unregister()

        // Register ⌘⌥O
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4352434C) // "CRCL"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.onToggle?()
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &eventHandler)

        // ⌘⌥O = cmdKey + optionKey + kVK_ANSI_O
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_O)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRef = nil

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit {
        unregister()
    }
}
```

**Step 2: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CircleApp/HotkeyManager.swift
git commit -m "feat: add global hotkey manager (⌘⌥O) via Carbon"
```

---

### Task 13: Settings UI (SwiftUI)

**Files:**
- Create: `CircleApp/Settings/SettingsWindowController.swift`
- Create: `CircleApp/Settings/SettingsView.swift`
- Create: `CircleApp/Settings/GeneralSettingsView.swift`
- Create: `CircleApp/Settings/ContentSettingsView.swift`

**Step 1: Write SettingsWindowController**

```swift
// CircleApp/Settings/SettingsWindowController.swift
import AppKit
import SwiftUI
import CircleKit

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Circle Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }
}
```

**Step 2: Write SettingsView**

```swift
// CircleApp/Settings/SettingsView.swift
import SwiftUI
import CircleKit

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            ContentSettingsView()
                .tabItem {
                    Label("Content", systemImage: "text.bubble")
                }
                .tag(1)
        }
        .frame(minWidth: 480, minHeight: 420)
        .padding()
    }
}
```

**Step 3: Write GeneralSettingsView**

```swift
// CircleApp/Settings/GeneralSettingsView.swift
import SwiftUI
import CircleKit

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Screensaver") {
                Toggle("Enabled", isOn: $settings.enabled)

                HStack {
                    Text("Idle Timeout")
                    Slider(value: .init(
                        get: { Double(settings.idleTimeout) },
                        set: { settings.idleTimeout = Int($0) }
                    ), in: 5...300, step: 5)
                    Text("\(settings.idleTimeout)s")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Ball") {
                Picker("Size Mode", selection: $settings.ballSizeMode) {
                    Text("Percentage").tag(BallSizeMode.percentage)
                    Text("Pixels").tag(BallSizeMode.pixels)
                }

                HStack {
                    Text("Size")
                    Slider(value: .init(
                        get: { Double(settings.ballSize) },
                        set: { settings.ballSize = Int($0) }
                    ), in: settings.ballSizeMode == .percentage ? 1...30 : 20...500)
                    Text("\(settings.ballSize)\(settings.ballSizeMode == .percentage ? "%" : "px")")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Opacity")
                    Slider(value: .init(
                        get: { Double(settings.ballOpacity) },
                        set: { settings.ballOpacity = Int($0) }
                    ), in: 10...100)
                    Text("\(settings.ballOpacity)%")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Speed")
                    Slider(value: .init(
                        get: { Double(settings.ballSpeed) },
                        set: { settings.ballSpeed = Int($0) }
                    ), in: 25...300)
                    Text("\(settings.ballSpeed)%")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Theme") {
                Picker("Theme", selection: $settings.theme) {
                    Text("Minimal").tag(ThemeID.minimal)
                    Text("Soft").tag(ThemeID.soft)
                }
                .pickerStyle(.segmented)
            }

            Section("Proximity Fade") {
                Toggle("Enabled", isOn: $settings.proximityFadeEnabled)

                if settings.proximityFadeEnabled {
                    HStack {
                        Text("Fade Radius")
                        Slider(value: .init(
                            get: { Double(settings.proximityFadeRadius) },
                            set: { settings.proximityFadeRadius = Int($0) }
                        ), in: 50...500)
                        Text("\(settings.proximityFadeRadius)px")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Other") {
                Toggle("Always On Mode (⌘⌥O)", isOn: $settings.alwaysOnMode)
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}
```

**Step 4: Write ContentSettingsView**

```swift
// CircleApp/Settings/ContentSettingsView.swift
import SwiftUI
import CircleKit

struct ContentSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Rotation") {
                Toggle("Auto-rotate content", isOn: $settings.contentRotationEnabled)

                if settings.contentRotationEnabled {
                    HStack {
                        Text("Interval")
                        Slider(value: .init(
                            get: { Double(settings.contentRotationInterval) },
                            set: { settings.contentRotationInterval = Int($0) }
                        ), in: 5...60, step: 5)
                        Text("\(settings.contentRotationInterval)s")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Clock") {
                Toggle("Show Clock", isOn: $settings.clockEnabled)

                if settings.clockEnabled {
                    Toggle("24-Hour Format", isOn: $settings.clockFormat24h)
                }
            }

            Section("System Info") {
                Toggle("Show System Info", isOn: $settings.systemInfoEnabled)

                if settings.systemInfoEnabled {
                    Toggle("Show Battery", isOn: $settings.showBattery)
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

**Step 5: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add CircleApp/Settings/
git commit -m "feat: add SwiftUI settings UI with General and Content tabs"
```

---

### Task 14: Screen Saver Plugin

**Files:**
- Create: `CircleSaver/CircleSaverView.swift`

**Step 1: Write CircleSaverView**

```swift
// CircleSaver/CircleSaverView.swift
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
```

**Step 2: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleSaver -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CircleSaver/CircleSaverView.swift
git commit -m "feat: add .saver screen saver plugin using CircleKit"
```

---

### Task 15: Launch at Login + App Icon

**Files:**
- Modify: `CircleApp/AppDelegate.swift` (add SMAppService)
- Create: `CircleApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Step 1: Add launch-at-login handling to AppDelegate**

Add to `applicationDidFinishLaunching` in `AppDelegate.swift`:

```swift
// In AppDelegate.swift, add import
import ServiceManagement

// Add to applicationDidFinishLaunching, after hotkey setup:
updateLoginItem()

// Add observer for settings changes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleSettingsChanged),
    name: SettingsManager.settingsChangedNotification,
    object: nil
)
```

Add method:

```swift
@objc private func handleSettingsChanged() {
    updateLoginItem()
    trayManager.updateMenu()
}

private func updateLoginItem() {
    do {
        if settings.launchAtLogin {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        print("[Circle] Failed to update login item: \(error)")
    }
}
```

**Step 2: Create AppIcon asset catalog**

```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 3: Verify it compiles**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CircleApp/AppDelegate.swift CircleApp/Resources/
git commit -m "feat: add launch-at-login via SMAppService and app icon asset catalog"
```

---

### Task 16: Integration Test — Build and Run

**Step 1: Build both targets**

```bash
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleApp -configuration Debug build 2>&1 | tail -5
xcodebuild -project CircleOLEDSaver.xcodeproj -scheme CircleSaver -configuration Debug build 2>&1 | tail -5
```

Expected: Both BUILD SUCCEEDED

**Step 2: Run unit tests**

```bash
xcodebuild test -project CircleOLEDSaver.xcodeproj -scheme CircleKit -destination "platform=macOS" 2>&1 | tail -10
```

Expected: All tests PASS

**Step 3: Run the app**

```bash
open build/Debug/Circle.app
```

Verify:
- Tray icon appears in menu bar
- Menu has Enable/Disable, Always On, Settings, Quit
- Settings window opens with General and Content tabs
- After idle timeout, circle appears and bounces
- Always On mode works (⌘⌥O)
- Circle fades near cursor

**Step 4: Install screen saver**

```bash
cp -R build/Debug/Circle.saver ~/Library/Screen\ Savers/
```

Verify: Circle appears in System Preferences > Screen Saver

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: Circle OLED Saver native macOS app — initial release"
```
