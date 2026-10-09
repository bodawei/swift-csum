// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-csum",
    platforms: [
        .macOS(.v13),
        .iOS(.v13)
    ],
    products: [
        .library(name: "ChecksumCore", targets: ["ChecksumCore"]),
        .executable(name: "csum-cli", targets: ["csum-cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "ChecksumCore"),
        .executableTarget(
            name: "csum-cli",
            dependencies: [
                "ChecksumCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
