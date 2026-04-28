import Foundation
import CoreGraphics

/// Layout for the icon + text composition rendered inside the bouncing ball.
/// Centers the icon+text group around the ball's center so single-line content
/// (clock) and multi-line content (Claude usage) both feel balanced.
struct CircleTextLayout {
    let iconFrame: CGRect
    let textFrame: CGRect
    let iconFontSize: CGFloat
    let textFontSize: CGFloat

    /// Local-coordinate layout for a ball of radius `size` whose center sits
    /// at (size, size) in the parent layer. CA coordinates: origin bottom-left.
    /// `lineCount` is the number of text lines (split by `\n`); icon is
    /// assumed to be a single glyph.
    static func compute(size: CGFloat, lineCount: Int) -> CircleTextLayout {
        let iconFontSize = size * 0.22
        let textFontSize = size * 0.14
        let iconHeight = iconFontSize * 1.5

        let lines = max(1, lineCount)
        let perLine = textFontSize * 1.2
        let lineSpacing = textFontSize * 0.5
        let textHeight = CGFloat(lines) * perLine + CGFloat(lines - 1) * lineSpacing

        let gap = textFontSize * 0.3
        let groupHeight = iconHeight + gap + textHeight

        // Center the group vertically around y=size.
        let groupTopY = size + groupHeight / 2          // upper edge (CA: max Y)
        let groupBottomY = size - groupHeight / 2       // lower edge (CA: min Y)

        let iconBottomY = groupTopY - iconHeight        // icon frame's min Y
        let textBottomY = groupBottomY                  // text frame's min Y

        return CircleTextLayout(
            iconFrame: CGRect(x: 0, y: iconBottomY, width: size * 2, height: iconHeight),
            textFrame: CGRect(x: 0, y: textBottomY, width: size * 2, height: textHeight),
            iconFontSize: iconFontSize,
            textFontSize: textFontSize
        )
    }

    /// Number of `\n`-separated lines in `text`, with a minimum of 1.
    static func lineCount(of text: String) -> Int {
        guard !text.isEmpty else { return 1 }
        return text.components(separatedBy: "\n").count
    }
}
