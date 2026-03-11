import SwiftUI
import CircleKit

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Screensaver") {
                Toggle("Enabled", isOn: $settings.enabled)

                HStack {
                    Text("Idle Timeout")
                    Slider(value: .init(
                        get: { Double(settings.idleTimeout) },
                        set: { settings.idleTimeout = Int($0) }
                    ), in: 5...300, step: 5)
                    Text("\(settings.idleTimeout)s")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Ball") {
                Picker("Size Mode", selection: $settings.ballSizeMode) {
                    Text("Percentage").tag(BallSizeMode.percentage)
                    Text("Pixels").tag(BallSizeMode.pixels)
                }

                HStack {
                    Text("Size")
                    Slider(value: .init(
                        get: { Double(settings.ballSize) },
                        set: { settings.ballSize = Int($0) }
                    ), in: settings.ballSizeMode == .percentage ? 1...30 : 20...500)
                    Text("\(settings.ballSize)\(settings.ballSizeMode == .percentage ? "%" : "px")")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Opacity")
                    Slider(value: .init(
                        get: { Double(settings.ballOpacity) },
                        set: { settings.ballOpacity = Int($0) }
                    ), in: 10...100)
                    Text("\(settings.ballOpacity)%")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Speed")
                    Slider(value: .init(
                        get: { Double(settings.ballSpeed) },
                        set: { settings.ballSpeed = Int($0) }
                    ), in: 25...300)
                    Text("\(settings.ballSpeed)%")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Theme") {
                Picker("Theme", selection: $settings.theme) {
                    Text("Minimal").tag(ThemeID.minimal)
                    Text("Soft").tag(ThemeID.soft)
                }
                .pickerStyle(.segmented)
            }

            Section("Proximity Fade") {
                Toggle("Enabled", isOn: $settings.proximityFadeEnabled)

                if settings.proximityFadeEnabled {
                    HStack {
                        Text("Fade Radius")
                        Slider(value: .init(
                            get: { Double(settings.proximityFadeRadius) },
                            set: { settings.proximityFadeRadius = Int($0) }
                        ), in: 50...500)
                        Text("\(settings.proximityFadeRadius)px")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Other") {
                Toggle("Always On Mode (⌘⌥O)", isOn: $settings.alwaysOnMode)
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}
