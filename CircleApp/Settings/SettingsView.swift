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
                .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
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

        SettingsSection("Options") {
            Toggle("Always On Mode", isOn: $settings.alwaysOnMode)
            HotkeyRecorderView()
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
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
            Toggle("Enabled", isOn: $settings.proximityFadeEnabled)

            if settings.proximityFadeEnabled {
                LabeledSlider(
                    label: "Fade Radius",
                    value: Binding(
                        get: { Double(settings.proximityFadeRadius) },
                        set: { settings.proximityFadeRadius = Int($0) }
                    ),
                    range: 50...500,
                    suffix: "px",
                    valueWidth: 55
                )
            }
        }
    }
}

// MARK: - Content Page

private struct ContentPageContent: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        SettingsSection("Rotation") {
            Toggle("Auto-rotate content", isOn: $settings.contentRotationEnabled)

            if settings.contentRotationEnabled {
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

            if settings.stockEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Symbols (comma-separated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("AAPL, GOOGL, TSLA", text: $settings.stockSymbols)
                        .textFieldStyle(.roundedBorder)
                }

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
