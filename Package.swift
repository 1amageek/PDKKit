// swift-tools-version: 6.3
import PackageDescription
import Foundation

let workspaceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let xcircuitePackageDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("XcircuitePackage/Package.swift").path
)
    ? .package(path: "../XcircuitePackage")
    : .package(url: "https://github.com/1amageek/XcircuitePackage.git", revision: "55b757efa6c906c30e829c2ca5b67566856dec6b")

let swiftMaskDataDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("swift-mask-data/Package.swift").path
)
    ? .package(path: "../swift-mask-data")
    : .package(url: "https://github.com/1amageek/swift-mask-data.git", revision: "9dcad7a886f0c7dc470062f3ab346fac6e1048db")

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
        xcircuitePackageDependency,
        swiftMaskDataDependency,
    ],
    targets: [
        .target(
            name: "PDKCore",
            dependencies: [.product(name: "XcircuitePackage", package: "XcircuitePackage")]
        ),
        .target(
            name: "PDKDiscovery",
            dependencies: [.product(name: "XcircuitePackage", package: "XcircuitePackage"), "PDKCore"]
        ),
        .target(
            name: "PDKValidation",
            dependencies: [
                .product(name: "XcircuitePackage", package: "XcircuitePackage"),
                "PDKCore",
                "PDKStandardViews",
            ]
        ),
        .target(
            name: "PDKStandardViews",
            dependencies: [
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
                .product(name: "LayoutIR", package: "swift-mask-data"),
                .product(name: "GDSII", package: "swift-mask-data"),
                .product(name: "OASIS", package: "swift-mask-data"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
