// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "FileCheck",
  platforms: [.macOS(.v10_15)],
  products: [
    .executable(name: "filecheck",
                targets: ["filecheck-tool"]),
    .library(
      name: "FileCheck",
      targets: ["FileCheck"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.0"),
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
