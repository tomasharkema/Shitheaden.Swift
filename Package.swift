// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Shitheaden", platforms: [
    .macOS(.v10_15),
  ],
  products: [
    .executable(name: "shitheaden", targets: ["shitheaden"]),
    .library(name: "ShitheadenRuntime", type: .static, targets: ["ShitheadenRuntime"]),
    .library(
      name: "ShitheadenShared",
      type: .static,
      targets: ["ShitheadenShared"] // , "ShitheadenSharedTests"]
    ),
    .library(name: "CustomAlgo", type: .static, targets: ["CustomAlgo"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/tomasharkema/swift-argument-parser.git",
      branch: "swift-5.5-async"
    ),
    .package(url: "https://github.com/tomasharkema/SwiftSocket", branch: "master"),
//        .package( url: "https://github.com/apple/swift-nio-ssh", from: "0.2.1")
    .package(url: "https://github.com/flintprocessor/ANSIEscapeCode", branch: "master"),
  ],
  targets: [
    .executableTarget(
      name: "shitheaden",
      dependencies: [
        .target(name: "ShitheadenRuntime"),
        .target(name: "CustomAlgo"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SwiftSocket", package: "SwiftSocket"),
        // , condition: .when(platforms: [.macOS, .macCatalyst])),
        .product(name: "ANSIEscapeCode", package: "ANSIEscapeCode"),
//        .product(name: "NIOSSH", package: "swift-nio-ssh"),
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
    .target(
      name: "ShitheadenRuntime",
      dependencies: ["ShitheadenShared"],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]),
      .define("DEBUG", .when(configuration: .debug))]
    ),

    .target(
      name: "ShitheadenShared",
      dependencies: [],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ])]
    ),
    .target(
      name: "CustomAlgo",
      dependencies: [
        .target(name: "ShitheadenShared"),
      ],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ])]
    ),
  ]
)
