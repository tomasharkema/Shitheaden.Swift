// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Shitheaden",
  platforms: [
    .macOS(.v12),
    .iOS(.v13),
    .tvOS(.v13),
  ],
  products: [
    .executable(name: "shitheaden", targets: ["shitheaden"]),
    .executable(
      name: "ShitheadenServer",
      targets: ["ShitheadenServer"]
    ),
    .library(
      name: "ShitheadenCLIRenderer",
      type: .static,
      targets: ["ShitheadenCLIRenderer"]
    ),
    .library(
      name: "ShitheadenRuntime",
      type: .static,
      targets: ["ShitheadenRuntime"]
    ),
    .library(
      name: "ShitheadenRuntimeDynamic",
      type: .dynamic,
      targets: ["ShitheadenRuntime"]
    ),
    .library(
      name: "ShitheadenShared",
      type: .static,
      targets: ["ShitheadenShared"]
    ),
    .library(name: "ShitheadenSharedDynamic", type: .dynamic, targets: ["ShitheadenRuntime"]),
    .library(name: "CustomAlgo", type: .static, targets: ["CustomAlgo"]),
    .library(name: "CustomAlgoDynamic", type: .dynamic, targets: ["CustomAlgo"]),
    .library(name: "AppDependencies", type: .static, targets: ["AppDependencies"]),
    .library(name: "AppDependenciesDynamic", type: .dynamic, targets: ["AppDependencies"]),
    .library(name: "TestsHelpers", type: .dynamic, targets: ["TestsHelpers"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.0.2"
    ),
    .package(url: "https://github.com/apple/swift-nio-ssh", from: "0.3.3"),
    .package(url: "https://github.com/flintprocessor/ANSIEscapeCode", from: "0.1.1"),
    .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
    .package(url: "https://github.com/chrisaljoudi/swift-log-oslog.git", from: "0.2.2"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.48.18"),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.52.2"),
    .package(url: "https://github.com/IBM-Swift/BlueSignals.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-nio-extras", from: "1.10.2"),
    .package(url: "https://github.com/tomasharkema/AsyncAwaitHelpers", branch: "main")
  ],
  targets: [
    .executableTarget(
      name: "shitheaden",
      dependencies: [
        .target(name: "ShitheadenRuntime"),
        .target(name: "ShitheadenCLIRenderer"),
        .target(name: "CustomAlgo"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "./Sources/ShitheadenCLI",
      swiftSettings: [
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release))
      ]
    ),
    .executableTarget(
      name: "ShitheadenServer",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .target(name: "CustomAlgo"),
        .target(name: "ShitheadenCLIRenderer"),
        .product(name: "NIOSSH", package: "swift-nio-ssh"),
        .product(name: "Signals", package: "BlueSignals"),
        .product(name: "NIOExtras", package: "swift-nio-extras"),
      ], swiftSettings: [
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release))
      ]
    ),
    .target(
      name: "AppDependencies",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(
          name: "LoggingOSLog",
          package: "swift-log-oslog",
          condition: .when(platforms: [.iOS, .macOS, .macCatalyst, .tvOS, .watchOS])
        ),
      ]
    ),
    .target(
      name: "ShitheadenCLIRenderer",
      dependencies: [
        .product(name: "ANSIEscapeCode", package: "ANSIEscapeCode"),
        .target(name: "ShitheadenRuntime"),
      ],
      swiftSettings: [
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release))
      ]
    ),
    .target(
      name: "ShitheadenRuntime",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "AsyncAwaitHelpers", package: "AsyncAwaitHelpers")
      ],
      swiftSettings: [
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release))
      ]
    ),
    .target(
      name: "ShitheadenShared",
      dependencies: [
        .product(name: "Logging", package: "swift-log")
      ]
    ),
    .target(
      name: "CustomAlgo",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .target(name: "ShitheadenRuntime"),
        .product(name: "Logging", package: "swift-log")
      ]
    ),
    .target(
      name: "TestsHelpers",
      dependencies: []
    ),
    .testTarget(
      name: "ShitheadenRuntimeTests",
      dependencies: [
        "ShitheadenRuntime",
        "CustomAlgo",
        "TestsHelpers",
      ],
      swiftSettings: [
      .define("DEBUG", .when(configuration: .debug)),
      .define("RELEASE", .when(configuration: .release)),
      .define("TESTING")]
    ),
    .testTarget(
      name: "ShitheadenSharedTests",
      dependencies: [
        "ShitheadenRuntime",
        "CustomAlgo",
        "TestsHelpers",
      ],
      swiftSettings: [
      .define("DEBUG", .when(configuration: .debug)),
      .define("RELEASE", .when(configuration: .release)),
      .define("TESTING")
      ]
    ),
    .testTarget(
      name: "CustomAlgoTests",
      dependencies: [
        "CustomAlgo",
        "TestsHelpers",
      ],
      swiftSettings: [
      .define("DEBUG", .when(configuration: .debug)),
      .define("RELEASE", .when(configuration: .release)),
      .define("TESTING")]
    ),
  ]
)
