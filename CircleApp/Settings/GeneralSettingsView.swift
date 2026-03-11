import SwiftUI
import CircleKit

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Screensaver
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

                // Ball
                SettingsSection("Ball") {
                    Picker("Size Mode", selection: $settings.ballSizeMode) {
                        Text("Percentage").tag(BallSizeMode.percentage)
                        Text("Pixels").tag(BallSizeMode.pixels)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

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

                // Theme
                SettingsSection("Theme") {
                    Picker("Theme", selection: $settings.theme) {
                        Text("Minimal").tag(ThemeID.minimal)
                        Text("Soft").tag(ThemeID.soft)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                // Proximity Fade
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

                // Other
                SettingsSection("Other") {
                    Toggle("Always On Mode (⌘⌥O)", isOn: $settings.alwaysOnMode)
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Reusable Components

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let suffix: String
    var valueWidth: CGFloat = 50

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 90, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text("\(Int(value))\(suffix)")
                .frame(width: valueWidth, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
