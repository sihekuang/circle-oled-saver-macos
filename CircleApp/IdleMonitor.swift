import Foundation
import CoreGraphics
import CircleKit

final class IdleMonitor {
    var onIdle: (() -> Void)?
    var onActive: (() -> Void)?

    private var timer: Timer?
    private(set) var isScreensaverActive = false
    private let pollInterval: TimeInterval = 1.0
    private var activity: NSObjectProtocol?
    private var suppressUntil: Date = .distantPast

    /// Temporarily ignore activity so hotkey presses don't dismiss the overlay.
    func suppressDismissal(for seconds: TimeInterval = 3.0) {
        suppressUntil = Date().addingTimeInterval(seconds)
    }

    func start() {
        guard timer == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Monitoring user idle state"
        )
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }

    private func checkIdleState() {
        let settings = SettingsManager.shared
        guard settings.enabled else { return }

        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let mouseClickIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)

        let minIdle = min(idleSeconds, min(keyboardIdle, mouseClickIdle))
        let threshold = TimeInterval(settings.idleTimeout)

        if !isScreensaverActive {
            if minIdle >= threshold {
                isScreensaverActive = true
                onIdle?()
            }
        } else {
            if minIdle < 2 && !settings.alwaysOnMode && Date() > suppressUntil {
                isScreensaverActive = false
                onActive?()
            }
        }
    }
}
