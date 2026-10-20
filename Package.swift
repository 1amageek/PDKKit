// swift-tools-version: 6.4
import PackageDescription

let swiftMaskDataDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/swift-mask-data.git",
    revision: "67410f834bdfa8a098c2ec0bfe3675210f658277"
)

let circuiteFoundationDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/CircuiteFoundation.git",
    revision: "5f132c58209123433e0e479e1ea61096e46061ba"
)

let coreSpiceDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/CoreSpice.git",
    revision: "5fa29e8accb1ff9de0d1e5f8bc9efe128accf0b7"
)

let package = Package(
    name: "PDKKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "PDKCore", targets: ["PDKCore"]),
        .library(name: "PDKSourceCapture", targets: ["PDKSourceCapture"]),
        .library(name: "PDKDiscovery", targets: ["PDKDiscovery"]),
        .library(name: "PDKProfileAdmission", targets: ["PDKProfileAdmission"]),
        .library(name: "PDKSpiceProfileInspection", targets: ["PDKSpiceProfileInspection"]),
        .library(name: "PDKValidation", targets: ["PDKValidation"]),
        .library(name: "PDKStandardViews", targets: ["PDKStandardViews"]),
        .library(name: "PDKKit", targets: ["PDKKit"]),
        .library(name: "PDKKitCLICore", targets: ["PDKKitCLICore"]),
        .executable(name: "pdkkit-cli", targets: ["PDKKitCLI"]),
    ],
    dependencies: [
        circuiteFoundationDependency,
        swiftMaskDataDependency,
        coreSpiceDependency,
    ],
    targets: [
        .target(
            name: "PDKSourceCapture",
            dependencies: [
                "PDKCore",
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
            exclude: ["DESIGN.md", "Identity/DESIGN.md", "Profile/DESIGN.md"]
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
            exclude: ["DESIGN.md", "ManifestLoading/DESIGN.md", "CandidateDiscovery/DESIGN.md"]
        ),
        .target(
            name: "PDKProfileAdmission",
            dependencies: [
                "PDKCore", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
            ],
            exclude: ["DESIGN.md", "Admission/DESIGN.md", "Consumption/DESIGN.md", "Consumption/ExecutionBinding/DESIGN.md"]
        ),
        .target(
            name: "PDKSpiceProfileInspection",
            dependencies: [
                "PDKCore", "PDKProfileAdmission", "PDKSourceCapture",
                .product(name: "CoreSpiceIO", package: "CoreSpice"),
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
            ],
            exclude: ["DESIGN.md"]
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
                "PDKProfileAdmission",
                "PDKDiscovery",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                "PDKCore",
                .product(name: "LayoutIR", package: "swift-mask-data"),
                .product(name: "GDSII", package: "swift-mask-data"),
                .product(name: "OASIS", package: "swift-mask-data"),
                .product(name: "LEF", package: "swift-mask-data"),
                .product(name: "TechIR", package: "swift-mask-data"),
            ],
            exclude: ["DESIGN.md", "StandardInspection/DESIGN.md", "ProfileInspection/DESIGN.md"]
        ),
        .target(
            name: "PDKKit",
            dependencies: ["PDKCore", "PDKDiscovery", "PDKValidation", "PDKStandardViews"]
        ),
        .target(
            name: "PDKKitCLICore",
            dependencies: [
                "PDKProfileAdmission",
                "PDKSpiceProfileInspection",
                "PDKCore",
                "PDKDiscovery",
                "PDKValidation",
                "PDKStandardViews",
                "PDKKit",
                "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ],
            exclude: ["DESIGN.md", "ProfileCommands/DESIGN.md"]
        ),
        .executableTarget(
            name: "PDKKitCLI",
            dependencies: ["PDKKitCLICore"]
        ),
        .testTarget(
            name: "PDKProfileCLITests",
            dependencies: [
                "PDKKitCLICore", "PDKCore", "PDKProfileAdmission", "PDKDiscovery", "PDKSourceCapture",
                "PDKSpiceProfileInspection", "PDKStandardViews",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                .product(name: "TechIR", package: "swift-mask-data"),
            ]
        ),
        .testTarget(
            name: "PDKProfileCLIInputTests",
            dependencies: [
                "PDKKitCLICore", "PDKCore", "PDKProfileAdmission", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKProfileOutputTests",
            dependencies: [
                "PDKKitCLICore", "PDKCore", "PDKProfileAdmission",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKSpiceProfileInspectionTests",
            dependencies: [
                "PDKSpiceProfileInspection", "PDKProfileAdmission", "PDKCore", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CoreSpiceIO", package: "CoreSpice"),
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKBudgetBootstrapTests",
            dependencies: ["PDKKitCLICore", "PDKCore"]
        ),
        .testTarget(
            name: "PDKStandardProfileInspectionTests",
            dependencies: [
                "PDKStandardViews", "PDKProfileAdmission", "PDKCore", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                .product(name: "TechIR", package: "swift-mask-data"),
            ]
        ),
        .testTarget(
            name: "PDKProfileAdmissionTests",
            dependencies: [
                "PDKProfileAdmission", "PDKCore", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKBoundedDecodingTests",
            dependencies: [
                "PDKCore", "PDKDiscovery", "PDKSourceCapture",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
            ]
        ),
        .testTarget(
            name: "PDKProfileValueTests",
            dependencies: [
                "PDKCore",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
            ]
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
                "PDKCore",
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
