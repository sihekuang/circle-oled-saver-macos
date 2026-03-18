import AppKit
import SwiftUI
import CircleKit

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Circle Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 720, height: 520)
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }
}
