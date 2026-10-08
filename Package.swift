// swift-tools-version: 6.3
import PackageDescription

let swiftMaskDataDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/swift-mask-data.git",
    revision: "75df136f942220379f6eeec5406c5270ffdbb31b"
)

let circuiteFoundationDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/CircuiteFoundation.git",
    exact: "26.812.0"
)

let package = Package(
    name: "PDKKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PDKCore", targets: ["PDKCore"]),
        .library(name: "PDKSourceCapture", targets: ["PDKSourceCapture"]),
        .library(name: "PDKDiscovery", targets: ["PDKDiscovery"]),
        .library(name: "PDKValidation", targets: ["PDKValidation"]),
        .library(name: "PDKStandardViews", targets: ["PDKStandardViews"]),
        .library(name: "PDKKit", targets: ["PDKKit"]),
        .library(name: "PDKKitCLICore", targets: ["PDKKitCLICore"]),
        .executable(name: "pdkkit-cli", targets: ["PDKKitCLI"]),
    ],
    dependencies: [
        circuiteFoundationDependency,
        swiftMaskDataDependency,
    ],
    targets: [
        .target(
            name: "PDKSourceCapture",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ],
            exclude: ["DESIGN.md", "Capture/DESIGN.md", "LocalCapture/DESIGN.md"]
        ),
        .target(
            name: "PDKCore",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ],
            exclude: ["DESIGN.md", "Identity/DESIGN.md"]
        ),
        .target(
            name: "PDKDiscovery",
            dependencies: [
                "PDKCore",
                "PDKSourceCapture",
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
            ],
            exclude: ["DESIGN.md", "ManifestLoading/DESIGN.md"]
        ),
        .target(
            name: "PDKValidation",
            dependencies: [
                "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                "PDKCore",
                "PDKDiscovery",
                "PDKStandardViews",
            ],
            exclude: ["DESIGN.md"]
        ),
        .target(
            name: "PDKStandardViews",
            dependencies: [
                "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                "PDKCore",
                .product(name: "LayoutIR", package: "swift-mask-data"),
                .product(name: "GDSII", package: "swift-mask-data"),
                .product(name: "OASIS", package: "swift-mask-data"),
                .product(name: "LEF", package: "swift-mask-data"),
            ],
            exclude: ["DESIGN.md", "StandardInspection/DESIGN.md"]
        ),
        .target(
            name: "PDKKit",
            dependencies: ["PDKCore", "PDKDiscovery", "PDKValidation", "PDKStandardViews"]
        ),
        .target(
            name: "PDKKitCLICore",
            dependencies: [
                "PDKCore",
                "PDKDiscovery",
                "PDKValidation",
                "PDKStandardViews",
                "PDKKit",
                "PDKSourceCapture",
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ]
        ),
        .executableTarget(
            name: "PDKKitCLI",
            dependencies: ["PDKKitCLICore"]
        ),
        .testTarget(
            name: "PDKDiscoveryTests",
            dependencies: [
                "PDKCore", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKSourceCaptureTests",
            dependencies: [
                "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKKitTests",
            dependencies: [
                "PDKSourceCapture",
                "PDKCore",
                "PDKDiscovery",
                "PDKValidation",
                "PDKStandardViews",
                "PDKKit",
                "PDKKitCLICore",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                .product(name: "LayoutIR", package: "swift-mask-data"),
                .product(name: "GDSII", package: "swift-mask-data"),
                .product(name: "OASIS", package: "swift-mask-data"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
