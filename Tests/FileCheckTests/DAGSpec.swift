import FileCheck
import XCTest
import Foundation

class DAGSpec : XCTestCase {
  func testPrefixOrderInvariant() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["BA", "AA"]) {
      // BA-DAG: this is the string to be {{matched}}
      print("this is the string to be matched")
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["AB", "BB"]) {
      // BB-DAG: this is the string to be {{matched}}
      print("this is the string to be matched")
    })
  }

  func testDAGWithInst() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-INSTDAG"]) {
      // CHECK-INSTDAG-DAG: add [[REG1:r[0-9]+]], r1, r2
      // CHECK-INSTDAG-DAG: add [[REG2:r[0-9]+]], r3, r4
      // CHECK-INSTDAG: mul r5, [[REG1]], [[REG2]]

      // CHECK-INSTDAG-DAG: mul [[REG1:r[0-9]+]], r1, r2
      // CHECK-INSTDAG-DAG: mul [[REG2:r[0-9]+]], r3, r4
      // CHECK-INSTDAG: add r5, [[REG1]], [[REG2]]

      // CHECK-INSTDAG-DAG: add [[REG1:r[0-9]+]], r1, r2
      // CHECK-INSTDAG-DAG: add [[REG2:r[0-9]+]], r3, r4
      // CHECK-INSTDAG-NOT: xor
      // CHECK-INSTDAG-DAG: mul r5, [[REG1]], [[REG2]]
      print([
        "add r10, r1, r2",
        "add r11, r3, r4",
        "mul r5, r10, r11",
        "",
        "mul r11, r3, r4",
        "mul r10, r1, r2",
        "add r5, r10, r11",
        "",
        "add r11, r3, r4",
        "add r10, r1, r2",
        "mul r5, r10, r11",
      ].joined(separator: "\n"))
    })
  }

  func testDAGXFailWithInst() {
    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["INSTDAG-XFAIL1"]) {
      // INSTDAG-XFAIL1: __x1
      // INSTDAG-XFAIL1-DAG: add [[REG1:r[0-9]+]], r1, r2
      // INSTDAG-XFAIL1-DAG: add [[REG2:r[0-9]+]], r3, r4
      // INSTDAG-XFAIL1: mul r5, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL1: __x1
      print([
        "__x1",
        "add r10, r1, r2",
        "add r11, r3, r4",
        "mul r5, r10, r12",
        "__x1",
      ].joined(separator: "\n"))
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["INSTDAG-XFAIL2"]) {
      // INSTDAG-XFAIL2: __x2
      // INSTDAG-XFAIL2-DAG: mul [[REG1:r[0-9]+]], r1, r2
      // INSTDAG-XFAIL2-DAG: mul [[REG2:r[0-9]+]], r3, r4
      // INSTDAG-XFAIL2: add r5, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL2: __x2
      print([
        "__x2",
        "mul r11, r3, r4",
        "mul r10, r1, r2",
        "add r5, r11, r11",
        "__x2",
      ].joined(separator: "\n"))
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["INSTDAG-XFAIL3"]) {
      // INSTDAG-XFAIL3: __x3
      // INSTDAG-XFAIL3-DAG: add [[REG1:r[0-9]+]], r1, r2
      // INSTDAG-XFAIL3-DAG: add [[REG2:r[0-9]+]], r3, r4
      // INSTDAG-XFAIL3-DAG: mul r5, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL3: __x3
      print([
        "__x3",
        "add r11, r3, r4",
        "add r12, r1, r2",
        "mul r5, r10, r11",
        "__x3",
      ].joined(separator: "\n"))
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["INSTDAG-XFAIL4"]) {
      // INSTDAG-XFAIL4: __x4
      // INSTDAG-XFAIL4-DAG: add [[REG1:r[0-9]+]], r1, r2
      // INSTDAG-XFAIL4-DAG: add [[REG2:r[0-9]+]], r3, r4
      // INSTDAG-XFAIL4-NOT: not
      // INSTDAG-XFAIL4-DAG: mul r5, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL4: __x4
      print([
        "__x4",
        "add r11, r3, r4",
        "add r12, r1, r2",
        "not",
        "mul r5, r12, r11",
        "__x4",
      ].joined(separator: "\n"))
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["INSTDAG-XFAIL5"]) {
      // INSTDAG-XFAIL5: __x5
      // INSTDAG-XFAIL5-DAG: add [[REG1:r[0-9]+]], r1, r2
      // INSTDAG-XFAIL5-DAG: add [[REG2:r[0-9]+]], r3, r4
      // INSTDAG-XFAIL5-NOT: not
      // INSTDAG-XFAIL5-DAG: mul r5, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL5: __x5
      print([
        "__x5",
        "mul r5, r12, r11",
        "add r11, r3, r4",
        "add r12, r1, r2",
        "not",
        "__x5",
      ].joined(separator: "\n"))
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["INSTDAG-XFAIL6"]) {
      // INSTDAG-XFAIL6: __x6
      // INSTDAG-XFAIL6-DAG: add [[REG1:r[0-9]+]], r1, r2
      // INSTDAG-XFAIL6-DAG: add [[REG2:r[0-9]+]], r3, r4
      // INSTDAG-XFAIL6-NOT: not
      // INSTDAG-XFAIL6-DAG: mul r5, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL6-DAG: mul r6, [[REG1]], [[REG2]]
      // INSTDAG-XFAIL6: __x6
      print([
        "__x6",
        "add r11, r3, r4",
        "mul r6, r12, r11",
        "add r12, r1, r2",
        "mul r5, r12, r11",
        "__x6",
      ].joined(separator: "\n"))
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testPrefixOrderInvariant", testPrefixOrderInvariant),
    ("testDAGWithInst", testDAGWithInst),
    ("testDAGXFailWithInst", testDAGXFailWithInst),
  ])
  #endif
}
