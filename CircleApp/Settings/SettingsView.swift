import SwiftUI
import CircleKit

enum SettingsPage: String, CaseIterable {
    case general
    case appearance
    case content
    case about

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .content: return "Content"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .appearance: return "paintbrush.pointed"
        case .content: return "text.bubble"
        case .about: return "info.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .purple
        case .content: return .green
        case .about: return .blue
        }
    }

    var section: String {
        switch self {
        case .general, .appearance, .content: return "Settings"
        case .about: return "Circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedPage: SettingsPage = .general

    private var sections: [(header: String, pages: [SettingsPage])] {
        let grouped = Dictionary(grouping: SettingsPage.allCases, by: \.section)
        let order = ["Settings", "Circle"]
        return order.compactMap { key in
            guard let pages = grouped[key] else { return nil }
            return (header: key, pages: pages)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(selection: $selectedPage) {
                ForEach(sections, id: \.header) { section in
                    Section(section.header) {
                        ForEach(section.pages, id: \.self) { page in
                            SidebarRow(page: page)
                                .tag(page)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(width: 200)

            // Detail
            DetailView(page: selectedPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                )
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let page: SettingsPage

    var body: some View {
        Label {
            Text(page.title)
        } icon: {
            Image(systemName: page.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(page.iconColor.gradient)
                )
        }
    }
}

// MARK: - Detail View

private struct DetailView: View {
    let page: SettingsPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Page header
                HStack(spacing: 10) {
                    Image(systemName: page.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(page.iconColor.gradient)
                        )
                    Text(page.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 4)

                // Page content
                switch page {
                case .general:
                    GeneralPageContent()
                case .appearance:
                    AppearancePageContent()
                case .content:
                    ContentPageContent()
                case .about:
                    AboutPageContent()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - General Page

private struct GeneralPageContent: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        if settings.enabled && settings.oledDisplayIDs.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("No displays selected. The screen saver won't appear on any screen.")
                    .font(.callout)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.yellow.opacity(0.15))
            )
        }

        SettingsSection("Screensaver") {
            Toggle("Enabled", isOn: $settings.enabled)

            LabeledSlider(
                label: "Idle Timeout",
                value: Binding(
                    get: { Double(settings.idleTimeout) },
                    set: { settings.idleTimeout = Int($0) }
                ),
                range: 5...300,
                step: 5,
                suffix: "s",
                valueWidth: 40
            )
        }

        SettingsSection("Displays") {
            Text("Select which screens are OLED.")
                .font(.caption)
                .foregroundColor(.secondary)

            DisplayListView(oledDisplayIDs: $settings.oledDisplayIDs)
        }

        SettingsSection("Options") {
            Toggle("Always On Mode", isOn: $settings.alwaysOnMode)
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        }

        SettingsSection("Menu Bar") {
            MenuBarAutoHideToggle()
            Text("Toggles the same setting as System Settings → Desktop & Dock → Automatically hide and show the menu bar. Requires Automation permission for System Events.")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Dock auto-hide is built into macOS — set it in System Settings. Circle doesn't bind a Dock hotkey; assign one yourself via macOS Shortcuts if you want one.")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        SettingsSection("Hotkeys") {
            HotkeyRecorderView(label: "Enable", hotkey: $settings.enableHotkey)
            HotkeyRecorderView(label: "Always On", hotkey: $settings.alwaysOnHotkey)
            HotkeyRecorderView(label: "Size Up", hotkey: $settings.sizeUpHotkey)
            HotkeyRecorderView(label: "Size Down", hotkey: $settings.sizeDownHotkey)
            HotkeyRecorderView(label: "Rotate", hotkey: $settings.rotateContentHotkey)
            HotkeyRecorderView(label: "Menu Bar Auto-Hide", hotkey: $settings.menuBarAutoHideHotkey)
        }
    }
}

// MARK: - Menu Bar Auto-Hide Toggle

/// Reads + writes macOS' menu-bar auto-hide preference. State is cached in
/// @State and refreshed on appear — drift is possible if the user toggles
/// via the hotkey while the Settings window is open, but reopening Settings
/// re-syncs. AppleScript failure (e.g. Automation permission not granted)
/// leaves the toggle visually flipped briefly and then snaps back when the
/// next render reads the unchanged source of truth.
private struct MenuBarAutoHideToggle: View {
    @State private var isHidden = false

    var body: some View {
        Toggle("Auto-hide macOS menu bar", isOn: Binding(
            get: { isHidden },
            set: { newValue in
                if let actual = MenuBarAutoHide.setHidden(newValue) {
                    isHidden = actual
                }
            }
        ))
        .onAppear {
            if let current = MenuBarAutoHide.isHidden {
                isHidden = current
            }
        }
    }
}

// MARK: - Appearance Page

private struct AppearancePageContent: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        SettingsSection("Theme") {
            Picker("Theme", selection: $settings.theme) {
                Text("Minimal").tag(ThemeID.minimal)
                Text("Soft").tag(ThemeID.soft)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }

        SettingsSection("Screen Saver") {
            HStack(spacing: 12) {
                Text("Size Mode")
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $settings.ballSizeMode) {
                    Text("Percentage").tag(BallSizeMode.percentage)
                    Text("Pixels").tag(BallSizeMode.pixels)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }

            LabeledSlider(
                label: "Size",
                value: Binding(
                    get: { Double(settings.ballSize) },
                    set: { settings.ballSize = Int($0) }
                ),
                range: settings.ballSizeMode == .percentage ? 1...30 : 20...500,
                suffix: settings.ballSizeMode == .percentage ? "%" : "px",
                valueWidth: 50
            )

            LabeledSlider(
                label: "Opacity",
                value: Binding(
                    get: { Double(settings.ballOpacity) },
                    set: { settings.ballOpacity = Int($0) }
                ),
                range: 10...100,
                suffix: "%",
                valueWidth: 50
            )

            LabeledSlider(
                label: "Speed",
                value: Binding(
                    get: { Double(settings.ballSpeed) },
                    set: { settings.ballSpeed = Int($0) }
                ),
                range: 25...300,
                suffix: "%",
                valueWidth: 50
            )
        }

        SettingsSection("Proximity Fade") {
            Text("Fades the ball out as your cursor approaches it, so it gets out of your way. The fade starts when the cursor enters the fade radius and reaches fully invisible before the cursor touches the ball.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProximityFadeDiagram()
                .padding(.vertical, 4)

            Toggle("Enabled", isOn: $settings.proximityFadeEnabled)

            HStack(spacing: 12) {
                Text("Radius Mode")
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $settings.proximityFadeMode) {
                    Text("Percentage").tag(BallSizeMode.percentage)
                    Text("Pixels").tag(BallSizeMode.pixels)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            .disabled(!settings.proximityFadeEnabled)

            LabeledSlider(
                label: "Fade Radius",
                value: Binding(
                    get: {
                        settings.proximityFadeMode == .percentage
                            ? Double(settings.proximityFadeRadiusPercent)
                            : Double(settings.proximityFadeRadius)
                    },
                    set: { newValue in
                        if settings.proximityFadeMode == .percentage {
                            settings.proximityFadeRadiusPercent = Int(newValue)
                        } else {
                            settings.proximityFadeRadius = Int(newValue)
                        }
                    }
                ),
                range: settings.proximityFadeMode == .percentage ? 5...100 : 50...1500,
                suffix: settings.proximityFadeMode == .percentage ? "%" : "px",
                valueWidth: 55
            )
            .disabled(!settings.proximityFadeEnabled)
        }
    }
}

// MARK: - Proximity Fade Diagram

private struct ProximityFadeDiagram: View {
    private let ballRadius: CGFloat = 14
    private let fadeRadius: CGFloat = 64
    private var cutoff: CGFloat { fadeRadius * 0.3 }

    var body: some View {
        HStack(spacing: 16) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Outer fade boundary (where fading starts)
                let outerRect = CGRect(
                    x: center.x - ballRadius - fadeRadius,
                    y: center.y - ballRadius - fadeRadius,
                    width: 2 * (ballRadius + fadeRadius),
                    height: 2 * (ballRadius + fadeRadius)
                )
                context.fill(Path(ellipseIn: outerRect), with: .color(.orange.opacity(0.15)))
                context.stroke(
                    Path(ellipseIn: outerRect),
                    with: .color(.orange.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

                // Inner cutoff boundary (fully invisible inside this)
                let innerRect = CGRect(
                    x: center.x - ballRadius - cutoff,
                    y: center.y - ballRadius - cutoff,
                    width: 2 * (ballRadius + cutoff),
                    height: 2 * (ballRadius + cutoff)
                )
                context.fill(Path(ellipseIn: innerRect), with: .color(.red.opacity(0.18)))
                context.stroke(
                    Path(ellipseIn: innerRect),
                    with: .color(.red.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

                // Ball
                let ballRect = CGRect(
                    x: center.x - ballRadius,
                    y: center.y - ballRadius,
                    width: 2 * ballRadius,
                    height: 2 * ballRadius
                )
                context.fill(Path(ellipseIn: ballRect), with: .color(.white.opacity(0.85)))

                // Cursor (at right edge, inside fade zone)
                let cursorPos = CGPoint(x: center.x + ballRadius + cutoff + 12, y: center.y)
                let arrow = Path { p in
                    p.move(to: cursorPos)
                    p.addLine(to: CGPoint(x: cursorPos.x + 8, y: cursorPos.y + 4))
                    p.addLine(to: CGPoint(x: cursorPos.x + 4, y: cursorPos.y + 4))
                    p.addLine(to: CGPoint(x: cursorPos.x + 6, y: cursorPos.y + 10))
                    p.addLine(to: CGPoint(x: cursorPos.x + 4, y: cursorPos.y + 11))
                    p.addLine(to: CGPoint(x: cursorPos.x + 2, y: cursorPos.y + 5))
                    p.addLine(to: CGPoint(x: cursorPos.x - 1, y: cursorPos.y + 8))
                    p.closeSubpath()
                }
                context.fill(arrow, with: .color(.white.opacity(0.9)))
            }
            .frame(width: 200, height: 160)
            .background(Color.black.opacity(0.85))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 8) {
                LegendRow(color: .white.opacity(0.85), title: "Ball", subtitle: "Always invisible if cursor enters")
                LegendRow(color: .red.opacity(0.6), title: "Invisible zone", subtitle: "Inner 30% of fade radius")
                LegendRow(color: .orange.opacity(0.6), title: "Fading zone", subtitle: "Quadratic falloff to 0")
                LegendRow(color: .gray.opacity(0.4), title: "Outside fade radius", subtitle: "Fully visible")
            }
            .font(.caption2)
        }
    }
}

private struct LegendRow: View {
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).fontWeight(.medium)
                Text(subtitle).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Content Page

private struct ContentPageContent: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        SettingsSection("Rotation") {
            LabeledSlider(
                label: "Interval",
                value: Binding(
                    get: { Double(settings.contentRotationInterval) },
                    set: { settings.contentRotationInterval = Int($0) }
                ),
                range: 5...60,
                step: 5,
                suffix: "s",
                valueWidth: 40
            )
        }

        SettingsSection("Clock") {
            Toggle("Show Clock", isOn: $settings.clockEnabled)

            if settings.clockEnabled {
                Toggle("24-Hour Format", isOn: $settings.clockFormat24h)
            }
        }

        SettingsSection("System Info") {
            Toggle("Show System Info", isOn: $settings.systemInfoEnabled)

            if settings.systemInfoEnabled {
                Toggle("Show Battery", isOn: $settings.showBattery)
            }
        }

        SettingsSection("Stocks") {
            Toggle("Show Stocks", isOn: $settings.stockEnabled)

            VStack(alignment: .leading, spacing: 4) {
                Text("Symbols (comma-separated)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("AAPL, GOOGL, TSLA", text: $settings.stockSymbols)
                    .textFieldStyle(.roundedBorder)
            }
            .disabled(!settings.stockEnabled)

            LabeledSlider(
                label: "Refresh",
                value: Binding(
                    get: { Double(settings.stockRefreshSeconds) },
                    set: { settings.stockRefreshSeconds = Int($0) }
                ),
                range: 60...600,
                step: 30,
                suffix: "s",
                valueWidth: 50
            )
            .disabled(!settings.stockEnabled)
        }

        SettingsSection("Claude Usage") {
            ClaudeUsageSettings(settings: settings)
        }
    }
}

// MARK: - Claude Usage section

private struct ClaudeUsageSettings: View {
    @ObservedObject var settings: SettingsManager
    @State private var keychainState: ClaudeCodeKeychainState = .unchecked
    @State private var testStatus: String = ""
    @State private var testStatusColor: Color = .secondary

    var body: some View {
        Group {
            Toggle("Show Claude Usage", isOn: Binding(
                get: { settings.claudeUsageEnabled },
                set: { newValue in
                    settings.claudeUsageEnabled = newValue
                    if newValue {
                        // First read of Claude Code's keychain entry — this is
                        // the moment macOS shows the permission prompt. Doing
                        // it here means the prompt fires while the user is in
                        // Settings (with our explanation visible right above)
                        // rather than later from the screensaver, out of context.
                        refreshKeychainState()
                    } else {
                        keychainState = .unchecked
                        testStatus = ""
                    }
                }
            ))

            HStack(spacing: 12) {
                Text("Display")
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: Binding(
                    get: { settings.claudeUsageMode },
                    set: { newValue in
                        DispatchQueue.main.async {
                            settings.claudeUsageMode = newValue
                        }
                    }
                )) {
                    Text("Session").tag(ClaudeUsageMode.today)
                    Text("Weekly").tag(ClaudeUsageMode.week)
                }
                .pickerStyle(.segmented)
            }
            .disabled(!settings.claudeUsageEnabled)

            Text("Shows your Claude subscription quota by calling Anthropic's /api/oauth/usage endpoint with the OAuth token Claude Code stores in your keychain. The token is used only for that API request and never leaves your Mac. Requires Claude Code installed and signed in.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                Text("macOS will prompt the first time Circle reads Claude Code's keychain entry — that's macOS asking your permission to share data between two apps. Pick \u{201C}Always Allow\u{201D} and Circle won't ask again.")
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                Text(refreshIntervalLabel)
                    .font(.caption2)
            }
            .foregroundColor(.secondary)

            statusBanner

            HStack(spacing: 8) {
                Button("Check Connection") {
                    runCheck()
                }
                .disabled(!settings.claudeUsageEnabled)
                if !testStatus.isEmpty {
                    Text(testStatus)
                        .font(.caption)
                        .foregroundColor(testStatusColor)
                }
                Spacer()
            }

            DisclosureGroup("Don't have Claude Code?") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Install Claude Code (the CLI) and sign in with a Claude subscription. The first time Circle reads the keychain, macOS will ask you to allow access — pick \u{201C}Always Allow\u{201D}.")
                        .font(.caption)
                    Text("If \u{201C}Allow\u{201D} prompts keep reappearing, that usually means CircleApp's signature changed (e.g. after a rebuild). Re-allow once.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .font(.caption)
        }
    }

    private var refreshIntervalLabel: String {
        let minutes = Int(ClaudeUsageProvider.pollInterval / 60)
        if minutes >= 1 {
            return "Refreshes every \(minutes) min — kept conservative to avoid Anthropic's rate limit."
        }
        let seconds = Int(ClaudeUsageProvider.pollInterval)
        return "Refreshes every \(seconds)s."
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch keychainState {
        case .unchecked:
            EmptyView()
        case .ok(let expiresIn):
            statusRow(
                icon: "checkmark.circle.fill",
                color: .green,
                text: "Claude Code signed in. Access token expires in \(expiresIn)."
            )
        case .okNoExpiry:
            statusRow(
                icon: "checkmark.circle.fill",
                color: .green,
                text: "Claude Code signed in."
            )
        case .notFound:
            statusRow(
                icon: "exclamationmark.circle.fill",
                color: .orange,
                text: "Claude Code keychain entry not found. Install Claude Code and sign in."
            )
        case .accessDenied:
            statusRow(
                icon: "lock.fill",
                color: .orange,
                text: "macOS denied keychain access. Tap Check Connection — when prompted, choose \u{201C}Always Allow\u{201D}."
            )
        case .error(let message):
            statusRow(
                icon: "exclamationmark.triangle.fill",
                color: .red,
                text: message
            )
        }
    }

    private func statusRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.15))
        )
    }

    private func refreshKeychainState() {
        let state = readKeychainState()
        keychainState = state
        applyAccessFlag(for: state)
    }

    private func runCheck() {
        // Force a fresh read — this is what triggers the macOS Always-Allow
        // prompt the first time, so it's a manual user action.
        testStatus = "Checking…"
        testStatusColor = .secondary
        let state = readKeychainState()
        keychainState = state
        applyAccessFlag(for: state)
        Task {
            await pingUsageEndpoint(state: state)
        }
    }

    /// Translates a keychain read result into the persistent access flag
    /// the screensaver provider checks before reading the keychain itself.
    /// Successful reads grant access; explicit denial revokes. Other states
    /// (notFound / unexpected) leave the flag untouched so a transient blip
    /// doesn't undo a prior approval.
    private func applyAccessFlag(for state: ClaudeCodeKeychainState) {
        switch state {
        case .ok, .okNoExpiry:
            settings.claudeUsageHasKeychainAccess = true
        case .accessDenied:
            settings.claudeUsageHasKeychainAccess = false
        case .unchecked, .notFound, .error:
            break
        }
    }

    private func pingUsageEndpoint(state: ClaudeCodeKeychainState) async {
        switch state {
        case .ok, .okNoExpiry:
            break
        default:
            await MainActor.run {
                testStatus = ""
            }
            return
        }
        let client = AnthropicUsageClient()
        do {
            let usage = try await client.fetchUsage()
            let week = usage.sevenDay.map { "\(Int($0.utilization.rounded()))% week" } ?? "no weekly data"
            await MainActor.run {
                testStatus = "OK — \(week)"
                testStatusColor = .green
            }
        } catch AnthropicUsageClient.ClientError.http(let code, _) {
            await MainActor.run {
                testStatus = "Anthropic returned \(code). Try `claude` in Terminal to refresh sign-in."
                testStatusColor = .red
            }
        } catch {
            await MainActor.run {
                testStatus = "Network failed: \(error.localizedDescription)"
                testStatusColor = .red
            }
        }
    }

    private func readKeychainState() -> ClaudeCodeKeychainState {
        switch ClaudeCodeKeychain.read() {
        case .success(let cred):
            guard let expiresAt = cred.expiresAt else {
                return .okNoExpiry
            }
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 0 {
                // Expired but Claude Code should refresh on next CLI invocation.
                return .error("Access token expired — open Claude Code to refresh, then check again.")
            }
            return .ok(expiresIn: ClaudeUsageProvider.formatTimeRemaining(seconds: remaining))
        case .failure(.notFound):
            return .notFound
        case .failure(.accessDenied):
            return .accessDenied
        case .failure(.malformed(let why)):
            return .error("Keychain entry exists but couldn't be parsed: \(why)")
        case .failure(.unexpectedStatus(let status)):
            return .error("Keychain returned status \(status).")
        }
    }
}

private enum ClaudeCodeKeychainState: Equatable {
    case unchecked
    case ok(expiresIn: String)
    case okNoExpiry
    case notFound
    case accessDenied
    case error(String)
}

// MARK: - About Page

private struct AboutPageContent: View {
    var body: some View {
        SettingsSection("Circle OLED Saver") {
            HStack(spacing: 16) {
                Image(nsName: "AppIcon")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Circle")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("OLED Screen Saver for macOS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Display List

private struct DisplayListView: View {
    @Binding var oledDisplayIDs: Set<String>
    @State private var screens: [(id: String, name: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(screens, id: \.id) { screen in
                Toggle(isOn: Binding(
                    get: { oledDisplayIDs.contains(screen.id) },
                    set: { enabled in
                        if enabled {
                            oledDisplayIDs.insert(screen.id)
                        } else {
                            oledDisplayIDs.remove(screen.id)
                        }
                    }
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: "display")
                            .foregroundColor(.secondary)
                        Text(screen.name)
                    }
                }
            }

            if screens.isEmpty {
                Text("No displays detected")
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button("Select All") {
                    oledDisplayIDs = Set(screens.map(\.id))
                }
                Button("Select None") {
                    oledDisplayIDs.removeAll()
                }
            }
            .font(.caption)
        }
        .onAppear { refreshScreens() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshScreens()
        }
    }

    private func refreshScreens() {
        screens = NSScreen.screens.enumerated().map { (i, screen) in
            let displayID = OverlayWindowController.displayID(for: screen)
            let name = screen.localizedName
            let size = screen.frame.size
            let label = "\(name) — \(Int(size.width))×\(Int(size.height))"
            return (id: displayID, name: label)
        }
    }
}

// MARK: - NSImage Helper

private extension Image {
    init(nsName: String) {
        if let nsImage = NSImage(named: nsName) {
            self.init(nsImage: nsImage)
        } else {
            self.init(systemName: "app.fill")
        }
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
