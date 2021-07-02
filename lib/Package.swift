// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Shitheaden",
  platforms: [
    .macOS(.v10_15),
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
      url: "https://github.com/tomasharkema/swift-argument-parser.git",
      branch: "swift-5.5-async"
    ),
    .package(url: "https://github.com/apple/swift-nio-ssh", from: "0.3.0"),
    .package(url: "https://github.com/flintprocessor/ANSIEscapeCode", branch: "master"),
    .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
    .package(url: "https://github.com/chrisaljoudi/swift-log-oslog.git", from: "0.2.1"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.48.6"),
    .package(url: "https://github.com/vapor/vapor.git", branch: "async-await"),
    .package(url: "https://github.com/IBM-Swift/BlueSignals.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-nio-extras", from: "1.10.0"),
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
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend",
          "-disable-availability-checking",
        ]),
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release)),
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
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend",
          "-disable-availability-checking",
        ]),
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release)),
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
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend", "-disable-availability-checking",
        ]),
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release)),
      ]
    ),
    .target(
      name: "ShitheadenRuntime",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .product(name: "Logging", package: "swift-log"
                ),
      ],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend",
          "-disable-availability-checking",
        ]),
        .define("DEBUG", .when(configuration: .debug)),
        .define("RELEASE", .when(configuration: .release)),
      ]
    ),
    .target(
      name: "ShitheadenShared",
      dependencies: [
        .product(name: "Logging", package: "swift-log"
                ),
      ],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend",
          "-disable-availability-checking",
        ]),
      ]
    ),
    .target(
      name: "CustomAlgo",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .target(name: "ShitheadenRuntime"),
        .product(name: "Logging", package: "swift-log"
                ),
      ],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend",
          "-disable-availability-checking",
        ]),
      ]
    ),
    .target(
      name: "TestsHelpers",
      dependencies: [],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend", "-disable-availability-checking",
        ]),
      ]
    ),
    .testTarget(
      name: "ShitheadenRuntimeTests",
      dependencies: [
        "ShitheadenRuntime",
        "CustomAlgo",
        "TestsHelpers",
      ],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
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
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug)),
      .define("RELEASE", .when(configuration: .release)),
      .define("TESTING")]
    ),
    .testTarget(
      name: "CustomAlgoTests",
      dependencies: [
        "CustomAlgo",
        "TestsHelpers",
      ],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug)),
      .define("RELEASE", .when(configuration: .release)),
      .define("TESTING")]
    ),
  ]
)
