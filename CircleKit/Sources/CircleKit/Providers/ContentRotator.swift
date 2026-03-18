import Foundation

public final class ContentRotator {
    public static let rotateNowNotification = Notification.Name("CircleContentRotateNow")

    private var providers: [ContentProvider]
    private var currentIndex = 0
    private var rotationTimer: Timer?
    private let intervalSeconds: Int
    private var rotateObserver: NSObjectProtocol?

    public var currentProvider: ContentProvider? {
        guard !providers.isEmpty else { return nil }
        return providers[currentIndex]
    }

    public init(providers: [ContentProvider], intervalSeconds: Int) {
        self.providers = providers
        self.intervalSeconds = intervalSeconds
    }

    public func next() {
        guard !providers.isEmpty else { return }
        currentIndex = (currentIndex + 1) % providers.count
    }

    public func start() {
        providers.forEach { $0.start() }

        if providers.count > 1 {
            rotationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { [weak self] _ in
                self?.next()
            }
        }

        rotateObserver = NotificationCenter.default.addObserver(
            forName: Self.rotateNowNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.next()
        }
    }

    public func stop() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        if let rotateObserver {
            NotificationCenter.default.removeObserver(rotateObserver)
        }
        rotateObserver = nil
        providers.forEach { $0.stop() }
    }
}
