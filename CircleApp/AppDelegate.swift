import AppKit
import ServiceManagement
import CircleKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var trayManager: TrayManager!
    private var overlayController: OverlayWindowController?
    private var idleMonitor: IdleMonitor!
    private var hotkeyManager: HotkeyManager!
    private let settings = SettingsManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Circle] applicationDidFinishLaunching called")
        print("[Circle] Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")

        // Prevent multiple instances
        let runningApps = NSWorkspace.shared.runningApplications
        let isAlreadyRunning = runningApps.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }.count > 0

        if isAlreadyRunning {
            print("[Circle] Another instance detected, quitting")
            NSApp.terminate(nil)
            return
        }

        print("[Circle] Setting up tray...")
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

        // Launch at login
        updateLoginItem()

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: SettingsManager.settingsChangedNotification,
            object: nil
        )

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
        guard settings.enabled, overlayController == nil else { return }
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

    private var settingsWindowController: SettingsWindowController?

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if let existing = settingsWindowController {
            existing.window?.makeKeyAndOrderFront(nil)
            existing.window?.orderFrontRegardless()
            return
        }

        let controller = SettingsWindowController()
        controller.showWindow(nil)
        controller.window?.orderFrontRegardless()
        settingsWindowController = controller
    }

    // MARK: - Settings Changes

    @objc private func handleSettingsChanged() {
        updateLoginItem()
        trayManager.updateMenu()
        hotkeyManager.register()

        if !settings.enabled {
            dismissOverlays()
        } else if settings.alwaysOnMode {
            showOverlays()
        }
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
