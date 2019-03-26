// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "FileCheck",
  products: [
    .library(
      name: "FileCheck",
      targets: ["FileCheck"]),
  ],
  targets: [
    .target(
      name: "FileCheck"),
    .testTarget(
      name: "FileCheckTests",
      dependencies: ["FileCheck"]),
  ]
)
