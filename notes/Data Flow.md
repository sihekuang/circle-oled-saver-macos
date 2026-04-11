# Data Flow

## App Startup

```
main.swift
    |
NSApplication.delegate = AppDelegate()
    |
applicationDidFinishLaunching()
    |- TrayManager (menu bar icon)
    |- IdleMonitor.start()
    |    '- onIdle -> showOverlays()
    |- HotkeyManager.register()
    |    |- onAlwaysOnToggle -> toggleAlwaysOn()
    |    |- onEnableToggle -> toggle settings.enabled
    |    |- onSizeUp/Down -> adjust settings.ballSize
    |    '- onRotateContent -> post rotateNowNotification
    |- SettingsManager.shared (load UserDefaults)
    '- NotificationCenter observers
         |- settingsChangedNotification
         '- didChangeScreenParametersNotification
```

## Overlay Display

```
IdleMonitor detects idle >= threshold
    |
AppDelegate.showOverlays()
    |
OverlayWindowController.show()
    |- For each NSScreen where isOLEDScreen:
    |    |- Create NSWindow (borderless, .screenSaver level)
    |    |- Create CircleOverlayView
    |    '- orderFrontRegardless()
    '- For each CircleOverlayView:
         |- Create CircleRenderer(hostLayer, bounds)
         |- renderer.start()  ->  CVDisplayLink
         '- Register mouse monitor  ->  proximity fade
```

## Rendering Loop

```
CVDisplayLink fires (~60fps)
    |
CircleRenderer.frame()  [dispatched to main thread]
    |- theme.tick(deltaTime)
    |- theme.updateMotion(state, bounds)
    |- BallPhysics.proximityOpacity()
    |- theme.updateAppearance(position, size, hue, opacity)
    '- theme.setContent(contentRotator.currentProvider.cachedData)
```

## Content Rotation

```
ContentRotator.start()
    |- Start all enabled providers
    '- Start rotation timer (if >1 provider)
         |
         |- On interval: next()
         '- On rotateNowNotification: next()
              |
              currentIndex = (currentIndex + 1) % count
              |
              CircleRenderer reads cachedData each frame
                  '- theme.setContent(data)
```

## Settings Change

```
Settings UI change
    |
SettingsManager @Published didSet
    |- UserDefaults.set(...)
    '- post settingsChangedNotification
         |
     CircleRenderer.settingsChanged()
         '- swap theme / update ball state
```

## See Also

- [[CircleKit#CircleRenderer]]
- [[CircleApp#AppDelegate]]
- [[Content Providers#ContentRotator]]
- [[Settings#Change Propagation]]
