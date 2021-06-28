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
    .library(name: "DependenciesTarget", type: .static, targets: ["DependenciesTarget"]),
    .library(name: "AppDependencies", type: .static, targets: ["AppDependencies"]),
    .library(name: "AppDependenciesDynamic", type: .dynamic, targets: ["AppDependencies"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/tomasharkema/swift-argument-parser.git",
      branch: "swift-5.5-async"
    ),
//    .package(url: "https://github.com/apple/swift-nio", from: "2.29.0"),
    .package(url: "https://github.com/apple/swift-nio-ssh", from: "0.3.0"),
    .package(url: "https://github.com/flintprocessor/ANSIEscapeCode", branch: "master"),
    .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
    .package(url: "https://github.com/chrisaljoudi/swift-log-oslog.git", from: "0.2.1"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.48.6"),
    .package(url: "https://github.com/vapor/vapor.git", branch: "async-await"),
  ],
  targets: [
    .executableTarget(
      name: "shitheaden",
      dependencies: [
        .target(name: "ShitheadenRuntime"),
        .target(name: "ShitheadenCLIRenderer"),
//        .target(name: "ShitheadenServer"),
//        .target(name: "CustomAlgo"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
//        .product(name: "ANSIEscapeCode", package: "ANSIEscapeCode"),
//        .product(name: "NIOSSH", package: "swift-nio-ssh"),
//        .product(name: "NIO", package: "swift-nio"),
//        .product(name: "NIOHTTP1", package: "swift-nio"),
//        .product(name: "NIOWebSocket", package: "swift-nio"),
//        .product(name: "Logging", package: "swift-log"),
//        .product(
//          name: "LoggingOSLog",
//          package: "swift-log-oslog",
//          condition: .when(platforms: [.iOS, .macOS, .macCatalyst, .tvOS, .watchOS])
//        ),
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
      ]
    ),
    .executableTarget(
      name: "ShitheadenServer",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .target(name: "CustomAlgo"),
        .target(name: "ShitheadenCLIRenderer"),
        .product(name: "NIOSSH", package: "swift-nio-ssh"),

      ], swiftSettings: [
        .unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend",
        "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug))]
    ),
    .target(
      name: "DependenciesTarget",
      dependencies: [
        .product(name: "ANSIEscapeCode", package: "ANSIEscapeCode"),
        .product(name: "NIOSSH", package: "swift-nio-ssh"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Logging", package: "swift-log"),
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
      ]
    ),
    .target(
      name: "ShitheadenRuntime",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend", "-disable-availability-checking",
        ]),
        .define("DEBUG", .when(configuration: .debug)),
      ]
    ),
    .testTarget(
      name: "ShitheadenRuntimeTests",
      dependencies: [
        "ShitheadenRuntime",
        "CustomAlgo",
      ],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug)),
      .define("TESTING")]
    ),
    .testTarget(
      name: "ShitheadenSharedTests",
      dependencies: [
        "ShitheadenRuntime",
        "CustomAlgo",
      ],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug)),
      .define("TESTING")]
    ),
    .target(
      name: "ShitheadenShared",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend", "-disable-availability-checking",
        ]),
      ]
    ),
    .target(
      name: "CustomAlgo",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .target(name: "ShitheadenRuntime"),
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend", "-disable-availability-checking",
        ]),
      ]
    ),
    .testTarget(
      name: "CustomAlgoTests",
      dependencies: [
        "CustomAlgo",
      ],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug)),
      .define("TESTING")]
    ),
  ]
)
