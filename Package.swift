// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Microya",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v10),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
        .library(
            name: "Microya",
            targets: ["Microya"])
    ],
    targets: [
        .target(
            name: "Microya",
            dependencies: [],
            path: "Frameworks/Microya",
            exclude: ["Frameworks/SupportingFiles"]
        )
    ]
)
