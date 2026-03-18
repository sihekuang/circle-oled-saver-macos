import SwiftUI

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
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
            )
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
