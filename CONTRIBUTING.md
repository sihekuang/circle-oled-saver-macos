# Contributing to Circle OLED Saver

Thanks for your interest in contributing!

## Development Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/sihekuang/oled-saver-macos.git
   cd oled-saver-macos
   ```

2. **Install XcodeGen** (if you don't have it)
   ```bash
   brew install xcodegen
   ```

3. **Generate the Xcode project**
   ```bash
   xcodegen generate
   ```

4. **Open in Xcode**
   ```bash
   open CircleOLEDSaver.xcodeproj
   ```

5. **Build and run** the `CircleApp` scheme.

## Running Tests

```bash
cd CircleKit && swift test
```

To run a single test:
```bash
cd CircleKit && swift test --filter BallPhysicsTests/testBounceChangesDirection
```

## Project Structure

All rendering logic lives in `CircleKit` (a Swift Package). `CircleApp` and `CircleSaver` are thin shells. If you're adding or changing animation behavior, themes, or content providers, you'll be working in `CircleKit/Sources/CircleKit/`.

See the [README](README.md) for a full architecture overview.

## Submitting Changes

1. Fork the repo and create a branch from `main`.
2. Make your changes. If you're adding a new feature, add tests in `CircleKit/Tests/CircleKitTests/`.
3. Run `swift test` in `CircleKit/` to make sure nothing is broken.
4. Open a pull request against `main`.

## Reporting Bugs

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if relevant (especially for visual bugs)
