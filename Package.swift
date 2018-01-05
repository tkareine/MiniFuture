// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "MiniFuture",
  products: [
    .library(name: "MiniFuture", targets: ["MiniFuture"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "MiniFuture", dependencies: [], path: "Source"),
    .target(name: "Benchmark", dependencies: ["MiniFuture"], path: "Benchmark"),
    .testTarget(name: "MiniFutureTests", dependencies: ["MiniFuture"], path: "Test")
  ],
  swiftLanguageVersions: [4]
)
