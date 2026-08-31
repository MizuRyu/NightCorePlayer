// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NightCoreDomain",
    // macOS を含めるのは simulator なしで `swift test` を回すため
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NightCoreDomain", targets: ["NightCoreDomain"]),
        .library(name: "NightCoreDomainTestSupport", targets: ["NightCoreDomainTestSupport"])
    ],
    targets: [
        .target(name: "NightCoreDomain"),
        .target(name: "NightCoreDomainTestSupport", dependencies: ["NightCoreDomain"]),
        .testTarget(
            name: "NightCoreDomainTests",
            dependencies: ["NightCoreDomain", "NightCoreDomainTestSupport"]
        )
    ]
)
