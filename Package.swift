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
    .executable(name: "Shitheaden", targets: ["Shitheaden"]),
    .library(name: "ShitheadenShared", type: .static, targets: ["ShitheadenShared"]),
    .library(name: "CustomAlgo", type: .static, targets: ["CustomAlgo"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "Shitheaden",
      dependencies: [
        .target(name: "ShitheadenShared"),
        .target(name: "CustomAlgo"),
      ],
      path: "Sources/Shitheaden",
      swiftSettings: [
        .unsafeFlags([
          "-Xfrontend",
          "-enable-experimental-concurrency",
          "-Xfrontend", "-disable-availability-checking",
        ]),
      ]
    ),

    .target(
      name: "ShitheadenShared",
      dependencies: [],
      path: "./Sources/ShitheadenShared"
    ),
    .target(
      name: "CustomAlgo",
      dependencies: [
        .target(name: "ShitheadenShared")],
      path: "./Sources/CustomAlgo"
    ),
  ]
)
