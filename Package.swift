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
    .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.1"),
    .package(url: "https://github.com/mxcl/Chalk.git", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "FileCheck",
      dependencies: ["Chalk"]),
    .target(
      name: "filecheck-tool",
      dependencies: ["FileCheck", "ArgumentParser"]),
    .testTarget(
      name: "FileCheckTests",
      dependencies: ["FileCheck"]),
  ]
)
