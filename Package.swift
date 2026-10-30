// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Campus",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Campus", targets: ["CampusApp"]), .library(name: "CampusCore", targets: ["CampusCore"])],
    targets: [
        .target(name: "CampusCore"),
        .executableTarget(name: "CampusApp", dependencies: ["CampusCore"], resources: [.process("Resources")]),
        .executableTarget(name: "CampusChecks", dependencies: ["CampusCore"], path: "Tests/CampusCoreTests")
    ]
)
