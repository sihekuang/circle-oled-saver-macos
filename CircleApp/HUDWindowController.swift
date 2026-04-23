import AppKit
import MacHUD

final class HUDController {
    static let shared = HUDController()

    private let hud = HUDManager.shared
    private let segmentCount = 16

    // MacHUD 0.5.2 has a debug assert in its fade-out path that fires when
    // displayAlert is called again while a prior alert is still dismissing.
    // Coalesce rapid-fire calls so at most one HUD flight is in progress.
    private let minInterval: TimeInterval = 0.2
    private var lastShownAt: Date = .distantPast

    func showAlwaysOnToggle(isOn: Bool) {
        let iconName = isOn ? "moon.fill" : "moon"
        show(.imageAndText(
            image: .static(.symbol(systemName: iconName)),
            title: "Always On"
        ))
    }

    func showEnableToggle(isOn: Bool) {
        let iconName = isOn ? "circle.fill" : "circle.slash"
        show(.imageAndText(
            image: .static(.symbol(systemName: iconName)),
            title: "Enabled"
        ))
    }

    func showSizeChange(fraction: Double) {
        show(.imageAndProgress(
            image: .static(.symbol(systemName: "arrow.up.left.and.arrow.down.right")),
            progressValue: .unitInterval(fraction, step: .segmentCount(segmentCount))
        ))
    }

    func showMenuBarAutoHideToggle(isOn: Bool) {
        let iconName = isOn ? "menubar.arrow.up.rectangle" : "menubar.rectangle"
        show(.imageAndText(
            image: .static(.symbol(systemName: iconName)),
            title: isOn ? "Menu Bar Auto-Hide" : "Menu Bar Visible"
        ))
    }

    func showContentRotation(contentName: String) {
        let iconName: String
        switch contentName.lowercased() {
        case "clock":
            iconName = "clock.fill"
        case "system info":
            iconName = "cpu"
        case "stocks":
            iconName = "chart.line.uptrend"
        default:
            iconName = "arrow.triangle.2.circlepath"
        }
        show(.imageAndText(
            image: .static(.symbol(systemName: iconName)),
            title: contentName
        ))
    }

    private func show(_ content: ProminentHUDStyle.AlertContent) {
        dispatchPrecondition(condition: .onQueue(.main))
        let now = Date()
        guard now.timeIntervalSince(lastShownAt) >= minInterval else { return }
        lastShownAt = now
        Task { @HUDManager in
            await hud.displayAlert(style: .prominent(), content: content)
        }
    }
}
