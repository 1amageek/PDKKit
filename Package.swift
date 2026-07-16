// swift-tools-version: 6.3
import PackageDescription
import Foundation

let workspaceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let isFullLSIWorkspace = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("Xcircuite/Package.swift").path
)

let swiftMaskDataDependency: Package.Dependency = isFullLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("swift-mask-data/Package.swift").path
)
    ? .package(path: "../swift-mask-data")
    : .package(url: "https://github.com/1amageek/swift-mask-data.git", revision: "9dcad7a886f0c7dc470062f3ab346fac6e1048db")

let circuiteFoundationDependency: Package.Dependency = isFullLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("CircuiteFoundation/Package.swift").path
)
    ? .package(path: "../CircuiteFoundation")
    : .package(url: "https://github.com/1amageek/CircuiteFoundation.git", revision: "8b5b1427280415e8acb3789cb364284b906f6cab")

let package = Package(
    name: "PDKKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PDKCore", targets: ["PDKCore"]),
        .library(name: "PDKDiscovery", targets: ["PDKDiscovery"]),
        .library(name: "PDKValidation", targets: ["PDKValidation"]),
        .library(name: "PDKStandardViews", targets: ["PDKStandardViews"]),
        .library(name: "PDKKit", targets: ["PDKKit"]),
        .library(name: "PDKKitCLICore", targets: ["PDKKitCLICore"]),
        .executable(name: "pdkkit", targets: ["PDKKitCLI"]),
    ],
    dependencies: [
        circuiteFoundationDependency,
        swiftMaskDataDependency,
    ],
    targets: [
        .target(
            name: "PDKCore",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
            ]
        ),
        .target(
            name: "PDKDiscovery",
            dependencies: ["PDKCore"]
        ),
        .target(
            name: "PDKValidation",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                "PDKCore",
                "PDKStandardViews",
            ]
        ),
        .target(
            name: "PDKStandardViews",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                "PDKCore",
                .product(name: "LayoutIR", package: "swift-mask-data"),
                .product(name: "GDSII", package: "swift-mask-data"),
                .product(name: "OASIS", package: "swift-mask-data"),
                .product(name: "LEF", package: "swift-mask-data"),
            ]
        ),
        .target(
            name: "PDKKit",
            dependencies: ["PDKCore", "PDKDiscovery", "PDKValidation", "PDKStandardViews"]
        ),
        .target(
            name: "PDKKitCLICore",
            dependencies: ["PDKCore", "PDKDiscovery", "PDKValidation", "PDKStandardViews", "PDKKit"]
        ),
        .executableTarget(
            name: "PDKKitCLI",
            dependencies: ["PDKKitCLICore"]
        ),
        .testTarget(
            name: "PDKKitTests",
            dependencies: [
                "PDKCore",
                "PDKDiscovery",
                "PDKValidation",
                "PDKStandardViews",
                "PDKKit",
                "PDKKitCLICore",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "LayoutIR", package: "swift-mask-data"),
                .product(name: "GDSII", package: "swift-mask-data"),
                .product(name: "OASIS", package: "swift-mask-data"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
