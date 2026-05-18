import AppKit

/// Reads and writes macOS' menu-bar auto-hide preference.
///
/// Reads go through `UserDefaults`'s cascade to `NSGlobalDomain._HIHideMenuBar` —
/// no Automation permission needed and no AppleScript launch cost, so it's
/// safe to call on view init / appear / every render.
///
/// Writes still go through AppleScript (the dock daemon owns the
/// authoritative state, and just writing the defaults key doesn't tell it
/// to re-render). That path requires the standard Automation permission
/// for Circle → System Events; failure returns nil so callers can revert
/// optimistic UI updates.
enum MenuBarAutoHide {
    /// macOS stores the setting at `NSGlobalDomain._HIHideMenuBar`.
    /// `UserDefaults.standard` cascades into the global domain for keys
    /// that aren't in the app's own plist, so this reads the system state
    /// without any prompts.
    static var isHidden: Bool {
        UserDefaults.standard.bool(forKey: "_HIHideMenuBar")
    }

    @discardableResult
    static func setHidden(_ hidden: Bool) -> Bool? {
        runBoolScript("""
        tell application "System Events"
            tell dock preferences
                set autohide menu bar to \(hidden ? "true" : "false")
                return autohide menu bar
            end tell
        end tell
        """)
    }

    @discardableResult
    static func toggle() -> Bool? {
        runBoolScript("""
        tell application "System Events"
            tell dock preferences
                set autohide menu bar to not autohide menu bar
                return autohide menu bar
            end tell
        end tell
        """)
    }

    private static func runBoolScript(_ source: String) -> Bool? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("[Circle] Menu bar auto-hide AppleScript failed: %@. Grant Automation permission to Circle in System Settings → Privacy & Security → Automation → System Events.", error)
            return nil
        }
        return result.booleanValue
    }
}
