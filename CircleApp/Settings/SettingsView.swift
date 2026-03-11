import SwiftUI
import CircleKit

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            ContentSettingsView()
                .tabItem {
                    Label("Content", systemImage: "text.bubble")
                }
                .tag(1)
        }
        .frame(minWidth: 480, minHeight: 420)
        .padding()
    }
}
