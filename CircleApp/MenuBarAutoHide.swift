import AppKit

/// Reads and writes macOS' menu-bar auto-hide preference via AppleScript.
/// Requires the Automation permission for Circle → System Events (the
/// standard macOS prompt fires on first call; failure returns nil so
/// callers can surface a "permission needed" hint).
enum MenuBarAutoHide {
    static var isHidden: Bool? {
        runBoolScript("""
        tell application "System Events"
            tell dock preferences
                return autohide menu bar
            end tell
        end tell
        """)
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
