import Foundation

public final class ClockProvider: BaseContentProvider {
    private let use24Hour: Bool

    public override var refreshInterval: TimeInterval { 1.0 }

    public init(use24Hour: Bool = false) {
        self.use24Hour = use24Hour
        super.init()
    }

    public override func fetchData() async {
        let now = Date()

        let timeFormatter = DateFormatter()
        if use24Hour {
            timeFormatter.dateFormat = "HH:mm"
        } else {
            timeFormatter.dateFormat = "h:mm a"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let time = timeFormatter.string(from: now)
        let date = dateFormatter.string(from: now)

        cachedData = ContentData(
            icon: "\u{1F550}",
            text: "\(time)\n\(date)"
        )
    }
}
