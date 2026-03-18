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
    @Published public var stockEnabled: Bool {
        didSet { defaults.set(stockEnabled, forKey: "stockEnabled"); notify() }
    }
    @Published public var stockSymbols: String {
        didSet { defaults.set(stockSymbols, forKey: "stockSymbols"); notify() }
    }
    @Published public var stockRefreshSeconds: Int {
        didSet { defaults.set(stockRefreshSeconds, forKey: "stockRefreshSeconds"); notify() }
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
            "stockEnabled": false,
            "stockSymbols": "AAPL, GOOGL, TSLA",
            "stockRefreshSeconds": 300,
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
        self.stockEnabled = defaults.bool(forKey: "stockEnabled")
        self.stockSymbols = defaults.string(forKey: "stockSymbols") ?? "AAPL, GOOGL, TSLA"
        self.stockRefreshSeconds = defaults.integer(forKey: "stockRefreshSeconds")
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.settingsChangedNotification, object: self)
    }
}
