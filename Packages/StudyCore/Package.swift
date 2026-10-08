// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StudyCore", targets: ["StudyCore"]),
    ],
    targets: [
        .target(name: "StudyCore"),
        .testTarget(name: "StudyCoreTests", dependencies: ["StudyCore"]),
    ]
)
