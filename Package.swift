// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "FileCheck",
  products: [
    .library(
      name: "FileCheck",
      targets: ["FileCheck"]),
    .executable(
      name: "file-check",
      targets: ["file-check"]),
  ],
  dependencies: [
    .package(url: "https://github.com/silt-lang/CommandLine.git", from: "4.0.0")
  ],
  targets: [
    .target(
      name: "file-check",
      dependencies: ["FileCheck", "CommandLine"]),
    .target(
      name: "FileCheck"),
    .testTarget(
      name: "FileCheckTests",
      dependencies: ["FileCheck"]),
  ]
)
