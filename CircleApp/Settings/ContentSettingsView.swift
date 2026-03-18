import SwiftUI
import CircleKit

struct ContentSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

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
            .padding(20)
        }
    }
}
