// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CircleKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CircleKit", targets: ["CircleKit"]),
    ],
    targets: [
        .target(name: "CircleKit"),
        .testTarget(name: "CircleKitTests", dependencies: ["CircleKit"]),
    ]
)
