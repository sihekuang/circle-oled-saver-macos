import AppKit
import ServiceManagement
import CircleKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var trayManager: TrayManager!
    private var overlayController: OverlayWindowController?
    private var idleMonitor: IdleMonitor!
    private var hotkeyManager: HotkeyManager!
    private let settings = SettingsManager.shared
    private let hud = HUDController.shared

    // Snapshot of settings that require expensive side-effects when they change.
    // Compared against current values in handleSettingsChanged() to avoid
    // tearing down overlays / re-registering hotkeys on every slider tick.
    private var lastOLEDDisplayIDs: Set<String> = []
    private var lastHotkeySnapshot: [String] = []
    private var lastEnabled = true
    private var lastLaunchAtLogin = false

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

        // Default all screens to selected on first launch
        if settings.oledDisplayIDs.isEmpty {
            settings.oledDisplayIDs = Set(NSScreen.screens.map { OverlayWindowController.displayID(for: $0) })
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

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onAlwaysOnToggle = { [weak self] in
            self?.idleMonitor.suppressDismissal()
            self?.toggleAlwaysOn()
            if let self { self.hud.showAlwaysOnToggle(isOn: self.settings.alwaysOnMode) }
        }
        hotkeyManager.onEnableToggle = { [weak self] in
            guard let self else { return }
            self.idleMonitor.suppressDismissal()
            self.settings.enabled.toggle()
            self.trayManager.updateMenu()
            self.hud.showEnableToggle(isOn: self.settings.enabled)
        }
        hotkeyManager.onSizeUp = { [weak self] in
            guard let self else { return }
            self.idleMonitor.suppressDismissal()
            let step = self.settings.ballSizeMode == .percentage ? 1 : 10
            let max = self.settings.ballSizeMode == .percentage ? 30 : 500
            self.settings.ballSize = min(self.settings.ballSize + step, max)
            self.hud.showSizeChange(fraction: self.sizeFraction())
        }
        hotkeyManager.onSizeDown = { [weak self] in
            guard let self else { return }
            self.idleMonitor.suppressDismissal()
            let step = self.settings.ballSizeMode == .percentage ? 1 : 10
            let min = self.settings.ballSizeMode == .percentage ? 1 : 20
            self.settings.ballSize = max(self.settings.ballSize - step, min)
            self.hud.showSizeChange(fraction: self.sizeFraction())
        }
        hotkeyManager.onRotateContent = { [weak self] in
            self?.idleMonitor.suppressDismissal()
            NotificationCenter.default.post(name: ContentRotator.rotateNowNotification, object: nil)
            self?.hud.showContentRotation(contentName: self?.currentContentName() ?? "Content")
        }
        hotkeyManager.onMenuBarAutoHideToggle = { [weak self] in
            guard let self else { return }
            self.idleMonitor.suppressDismissal()
            if let isOn = self.toggleMenuBarAutoHide() {
                self.hud.showMenuBarAutoHideToggle(isOn: isOn)
            }
        }
        hotkeyManager.register()

        // Initialize change-tracking snapshot
        lastOLEDDisplayIDs = settings.oledDisplayIDs
        lastHotkeySnapshot = currentHotkeySnapshot()
        lastEnabled = settings.enabled
        lastLaunchAtLogin = settings.launchAtLogin

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

    // MARK: - Menu Bar Auto-Hide

    private func toggleMenuBarAutoHide() -> Bool? {
        let script = """
        tell application "System Events"
            tell dock preferences
                set autohide menu bar to not autohide menu bar
                return autohide menu bar
            end tell
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            print("[Circle] Menu bar auto-hide toggle failed: \(error)")
            return nil
        }
        return result.booleanValue
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
        trayManager.updateMenu()

        if settings.launchAtLogin != lastLaunchAtLogin {
            updateLoginItem()
            lastLaunchAtLogin = settings.launchAtLogin
        }

        let hotkeySnapshot = currentHotkeySnapshot()
        if hotkeySnapshot != lastHotkeySnapshot {
            hotkeyManager.register()
            lastHotkeySnapshot = hotkeySnapshot
        }

        let enabledChanged = settings.enabled != lastEnabled
        let displaysChanged = settings.oledDisplayIDs != lastOLEDDisplayIDs
        lastEnabled = settings.enabled
        lastOLEDDisplayIDs = settings.oledDisplayIDs

        if enabledChanged && !settings.enabled {
            dismissOverlays()
        } else if displaysChanged, settings.alwaysOnMode || overlayController != nil {
            // Display selection changed — recreate overlays to attach to the new set.
            dismissOverlays()
            showOverlays()
        }
        // Other settings (proximity fade, opacity, speed, theme, content) are read
        // live by CircleRenderer each frame, so no overlay recreation is needed.
    }

    private func currentHotkeySnapshot() -> [String] {
        [
            settings.alwaysOnHotkey,
            settings.enableHotkey,
            settings.sizeUpHotkey,
            settings.sizeDownHotkey,
            settings.rotateContentHotkey,
            settings.menuBarAutoHideHotkey,
        ]
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
        guard overlayController != nil else { return }
        dismissOverlays()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.settings.alwaysOnMode || self.idleMonitor.isScreensaverActive {
                self.showOverlays()
            }
        }
    }

    // MARK: - HUD Helpers

    private func sizeFraction() -> Double {
        let minVal = settings.ballSizeMode == .percentage ? 1 : 20
        let maxVal = settings.ballSizeMode == .percentage ? 30 : 500
        return Double(settings.ballSize - minVal) / Double(maxVal - minVal)
    }

    private func currentContentName() -> String {
        // Determine which content is next based on enabled providers
        // The rotator cycles through enabled content types
        let enabledTypes: [String] = {
            var types: [String] = []
            if settings.clockEnabled { types.append("Clock") }
            if settings.systemInfoEnabled { types.append("System Info") }
            if settings.stockEnabled { types.append("Stocks") }
            return types
        }()
        // We can't know the exact rotator index, so show the next likely content
        // For a simple approach, just show "Content" if we can't determine
        return enabledTypes.first ?? "Content"
    }

    private func cleanup() {
        hotkeyManager.unregister()
        idleMonitor.stop()
        dismissOverlays()
    }
}
