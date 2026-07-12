// swift-tools-version: 6.3
import PackageDescription

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
        .package(url: "https://github.com/1amageek/XcircuitePackage.git", branch: "main"),
        .package(url: "https://github.com/1amageek/swift-mask-data.git", branch: "main"),
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
