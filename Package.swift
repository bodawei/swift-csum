// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-csum",
    platforms: [
        .macOS(.v13),
        .iOS(.v13)
    ],
    products: [
        .library(name: "CsumController", targets: ["CsumController"]),
        .executable(name: "csum-cli", targets: ["csum-cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "CsumController"),
        .testTarget(
            name: "CsumControllerTests",
            dependencies: ["CsumController"]
        ),
        .executableTarget(
            name: "csum-cli",
            dependencies: [
                "CsumController",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
