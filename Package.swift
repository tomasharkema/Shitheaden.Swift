// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Shitheaden",
//  platforms: [
//    .macOS(),
//  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .executable(name: "ShitheadenCLI", targets: ["ShitheadenCLI"]),
    .library(name: "Shitheaden", type: .static, targets: ["Shitheaden"]),
    .library(
      name: "ShitheadenShared",
      type: .static,
      targets: ["ShitheadenShared"]//, "ShitheadenSharedTests"]
    ),
    .library(name: "CustomAlgo", type: .static, targets: ["CustomAlgo"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "ShitheadenCLI",
      dependencies: [
        .target(name: "Shitheaden"),
        .target(name: "CustomAlgo"),
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
      name: "Shitheaden",
      dependencies: ["ShitheadenShared"],
      swiftSettings: [.unsafeFlags([
        "-Xfrontend",
        "-enable-experimental-concurrency",
        "-Xfrontend", "-disable-availability-checking",
      ]), .define("DEBUG", .when(configuration: .debug))]
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

//    .testTarget(name: "ShitheadenSharedTests"),
  ]
)
