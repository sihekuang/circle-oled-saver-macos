import AppKit
import MacHUD

final class HUDController {
    static let shared = HUDController()

    private let hud = HUDManager.shared
    private let segmentCount = 16

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
        Task { @HUDManager in
            await hud.displayAlert(style: .prominent(), content: content)
        }
    }
}
