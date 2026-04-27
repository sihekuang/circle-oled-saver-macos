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
            Toggle("Show Claude Token Usage", isOn: $settings.claudeUsageEnabled)

            Text("Aggregates Claude tokens used on this Mac via the Claude Code CLI (reads ~/.claude/projects). Requires the Claude Code CLI to be installed and used. Tokens used through the web app or other devices are not included.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Text("Display")
                    .frame(width: 90, alignment: .leading)
                Picker("", selection: $settings.claudeUsageMode) {
                    Text("Today").tag(ClaudeUsageMode.today)
                    Text("This Week").tag(ClaudeUsageMode.week)
                }
                .pickerStyle(.segmented)
            }
            .disabled(!settings.claudeUsageEnabled)

            LabeledSlider(
                label: "Weekly Goal",
                value: Binding(
                    get: { Double(settings.claudeUsageWeeklyGoalMTokens) },
                    set: { settings.claudeUsageWeeklyGoalMTokens = Int($0) }
                ),
                range: 100...10000,
                step: 100,
                suffix: "M",
                valueWidth: 60
            )
            .disabled(!settings.claudeUsageEnabled)

            HStack {
                Spacer()
                Button("Suggest from last 4 weeks") {
                    Task.detached(priority: .userInitiated) {
                        let suggested = ClaudeUsageProvider.suggestWeeklyGoalMTokens()
                        await MainActor.run {
                            SettingsManager.shared.claudeUsageWeeklyGoalMTokens = suggested
                        }
                    }
                }
                .disabled(!settings.claudeUsageEnabled)
            }
        }
    }
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
