import Foundation

public protocol ContentProvider: AnyObject {
    var refreshInterval: TimeInterval { get }
    var cachedData: ContentData? { get }

    func fetchData() async
    func start()
    func stop()
}

public class BaseContentProvider: ContentProvider {
    public var cachedData: ContentData?
    public var refreshInterval: TimeInterval { 1.0 }

    private var timer: Timer?
    private var isFetching = false

    public init() {}

    public func fetchData() async {
        // Override in subclass
    }

    public func start() {
        // Initial fetch
        Task { await fetchData() }

        // Setup timer on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self, !self.isFetching else { return }
            self.isFetching = true
            Task {
                await self.fetchData()
                self.isFetching = false
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        cachedData = nil
    }
}
