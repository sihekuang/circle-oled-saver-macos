# Idle Detection

**File**: `CircleApp/IdleMonitor.swift`

Polls system idle time every 1 second using `CGEventSource`.

## How It Works

Checks three event sources and takes the minimum:
- `CGEventSource.secondsSinceLastEventType(.mouseMoved)`
- `CGEventSource.secondsSinceLastEventType(.keyDown)`
- `CGEventSource.secondsSinceLastEventType(.leftMouseDown)`

## State Machine

| Current State | Condition | Action |
|--------------|-----------|--------|
| Not active | `minIdle >= threshold` | Call `onIdle()` -> show overlays |
| Active | `minIdle < 2s` AND no suppression AND not always-on | Call `onActive()` -> dismiss overlays |

## Suppression

`suppressDismissal(for:)` sets a `suppressUntil` timestamp to prevent immediate dismissal when a hotkey is pressed (since the keypress itself counts as activity).

## Configuration

- Idle timeout configurable via [[Settings]] (`idleTimeout`, default 10s)
- Always-on mode bypasses active-state dismissal

## See Also

- [[CircleApp#AppDelegate]]
- [[Hotkey System]]
