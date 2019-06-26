// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "FileCheck",
  products: [
    .executable(name: "filecheck",
                targets: ["filecheck-tool"]),
    .library(
      name: "FileCheck",
      targets: ["FileCheck"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
  ],
  targets: [
    .target(
      name: "FileCheck"),
    .target(
      name: "filecheck-tool",
      dependencies: ["FileCheck", "SPMUtility", "Rainbow"]),
    .testTarget(
      name: "FileCheckTests",
      dependencies: ["FileCheck"]),
  ]
)
