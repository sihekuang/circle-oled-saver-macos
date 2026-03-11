import SwiftUI
import CircleKit

struct ContentSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Rotation") {
                Toggle("Auto-rotate content", isOn: $settings.contentRotationEnabled)

                if settings.contentRotationEnabled {
                    HStack {
                        Text("Interval")
                        Slider(value: .init(
                            get: { Double(settings.contentRotationInterval) },
                            set: { settings.contentRotationInterval = Int($0) }
                        ), in: 5...60, step: 5)
                        Text("\(settings.contentRotationInterval)s")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Clock") {
                Toggle("Show Clock", isOn: $settings.clockEnabled)

                if settings.clockEnabled {
                    Toggle("24-Hour Format", isOn: $settings.clockFormat24h)
                }
            }

            Section("System Info") {
                Toggle("Show System Info", isOn: $settings.systemInfoEnabled)

                if settings.systemInfoEnabled {
                    Toggle("Show Battery", isOn: $settings.showBattery)
                }
            }
        }
        .formStyle(.grouped)
    }
}
