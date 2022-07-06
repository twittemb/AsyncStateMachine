// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "AsyncStateMachine",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "AsyncStateMachine",
            targets: ["AsyncStateMachine"]),
    ],
    dependencies: [
      .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay.git", exact: Version("0.3.3"))
    ],
    targets: [
        .target(
            name: "AsyncStateMachine",
            dependencies: [
              .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay")
            ],
            path: "Sources"),
        .testTarget(
            name: "AsyncStateMachineTests",
            dependencies: ["AsyncStateMachine"],
            path: "Tests"),
    ]
)
