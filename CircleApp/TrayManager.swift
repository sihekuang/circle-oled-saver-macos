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
            button.image = NSImage(named: "TrayIcon")
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

        let enableItem = NSMenuItem(
            title: settings.enabled ? "🟢 Enabled" : "🔴 Disabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enableItem.target = self
        menu.addItem(enableItem)

        menu.addItem(.separator())

        let alwaysOnItem = NSMenuItem(
            title: "Always On",
            action: #selector(alwaysOnClicked),
            keyEquivalent: ""
        )
        alwaysOnItem.target = self
        alwaysOnItem.state = settings.alwaysOnMode ? .on : .off
        menu.addItem(alwaysOnItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

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
