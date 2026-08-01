// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "StripTimer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StripTimer", targets: ["StripTimer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "StripTimer",
            dependencies: []
        )
    ]
)
