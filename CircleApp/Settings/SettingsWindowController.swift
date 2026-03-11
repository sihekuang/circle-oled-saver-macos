import AppKit
import SwiftUI
import CircleKit

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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
