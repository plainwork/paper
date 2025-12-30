// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "paper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "paper", targets: ["paper"])
    ],
    targets: [
        .executableTarget(
            name: "paper"
        )
    ]
)
