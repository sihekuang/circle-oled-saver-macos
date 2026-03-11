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
            }
            .padding(20)
        }
    }
}
