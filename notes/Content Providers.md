# Content Providers

**Path**: `CircleKit/Sources/CircleKit/Providers/`

## ContentProvider Protocol

**File**: `ContentProvider.swift`

```swift
protocol ContentProvider {
    var refreshInterval: TimeInterval { get }
    var cachedData: ContentData? { get }
    func fetchData() async
    func start()
    func stop()
}
```

`BaseContentProvider` provides default timer-based refresh with `async/await` support and `isFetching` guard.

## Providers

### ClockProvider

**File**: `ClockProvider.swift`
- **Refresh**: 1.0s
- **Icon**: clock emoji
- **Data**: Current time + date
- Supports 12h/24h format via [[Settings]]

### SystemInfoProvider

**File**: `SystemInfoProvider.swift`
- **Refresh**: 2.0s
- **Icon**: chart emoji
- **Data**: CPU %, Memory usage, Battery level
- CPU via Mach kernel APIs
- Memory via `vm_statistics64`
- Battery via `IOKit.ps`

### StockProvider

**File**: `StockProvider.swift`
- **Refresh**: 300s (configurable)
- **Icon**: chart emoji
- **Data**: Stock price + % change
- Source: Yahoo Finance API (`/v8/finance/chart/{symbol}`)
- Cycles through configured symbols

## ContentRotator

**File**: `ContentRotator.swift`

Manages the list of active providers and rotates between them on a timer.

- `next()` advances `currentIndex` modulo provider count
- Listens for `rotateNowNotification` (triggered by [[Hotkey System|rotate content hotkey]])
- Only starts rotation timer if more than one provider is active

## See Also

- [[Themes]] (themes call `setContent` to display provider data)
- [[Settings]] (controls which providers are enabled)
- [[Data Flow]]
