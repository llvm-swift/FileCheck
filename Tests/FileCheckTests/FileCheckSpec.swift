import FileCheck
import XCTest
import Foundation

class FileCheckSpec : XCTestCase {
  func testWhitespace() {
    // Check that CHECK-NEXT without a space after the colon works.
    // Check that CHECK-NOT without a space after the colon works.
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["WHITESPACE1", "WHITESPACE2"]) {
      // WHITESPACE1:a
      // WHITESPACE1-NEXT:b
      print("a")
      print("b")

      // WHITESPACE2-NOT:foo
      print("oo")
    })
  }

  func testSame() {
    XCTAssert(fileCheckOutput(withPrefixes: ["SAME1"]) {
      // SAME1: foo
      // SAME1-SAME: bat
      // SAME1-SAME: bar
      // SAME1-NEXT: baz
      print("foo bat bar")
      print("baz")
    })

    XCTAssert(fileCheckOutput(withPrefixes: ["SAME2"]) {
      // SAME2: foo
      // SAME2-NOT: baz
      // SAME2-SAME: bar
      // SAME2-NEXT: baz
      print("foo bat bar")
      print("baz")
    })

    XCTAssertFalse(fileCheckOutput(withPrefixes: ["FAIL-SAME1"]) {
      // FAIL-SAME1: foo
      // FAIL-SAME1-SAME: baz
      print("foo bat bar")
      print("baz")
    })

    XCTAssertFalse(fileCheckOutput(withPrefixes: ["FAIL-SAME2"]) {
      // FAIL-SAME2: foo
      // FAIL-SAME2-NOT: bat
      // FAIL-SAME2-SAME: bar
      print("foo bat bar")
      print("baz")
    })
  }

  func testCheckDAG() {
    XCTAssert(fileCheckOutput(withPrefixes: ["TESTDAG"]) {
      print("")
      // TESTDAG-DAG: add [[REG1:r[0-9]+]], r1, r2
      print("add r10, r1, r2")
      // TESTDAG-DAG: add [[REG2:r[0-9]+]], r3, r4
      print("add r11, r3, r4")
      // TESTDAG: mul r5, [[REG1]], [[REG2]]
      print("mul r5, r10, r11")

      // TESTDAG-DAG: mul [[REG1:r[0-9]+]], r1, r2
      print("mul r11, r3, r4")
      // TESTDAG-DAG: mul [[REG2:r[0-9]+]], r3, r4
      print("mul r10, r1, r2")
      // TESTDAG: add r5, [[REG1]], [[REG2]]
      print("add r5, r10, r11")

      // TESTDAG-DAG: add [[REG1:r[0-9]+]], r1, r2
      // TESTDAG-DAG: add [[REG2:r[0-9]+]], r3, r4
      // TESTDAG-NOT: xor
      // TESTDAG-DAG: mul r5, [[REG1]], [[REG2]]
      print("add r11, r3, r4")
      print("add r10, r1, r2")
      print("mul r5, r10, r11")
    })
  }

  func testImplicitCheckNot() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-NOTCHECK"]) {
      // CHECK-NOTCHECK: error: NOTCHECK-NOT: string occurred!
      // CHECK-NOTCHECK-NEXT: warning:
      // CHECK-NOTCHECK-NEXT: note: NOTCHECK-NOT: pattern specified here
      // CHECK-NOTCHECK-NEXT: IMPLICIT-CHECK-NOT: warning:
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["NOTCHECK"], checkNot: ["warning:"], options: [.disableColors]) {
        // NOTCHECK: error:
        print("error:")
        // NOTCHECK: error:
        print("error:")
        // NOTCHECK: error:
        print("error:")
        // NOTCHECK: error:
        print("error:")
        print("warning:")
      })
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-NOTCHECK-MID"]) {
      // CHECK-NOTCHECK-MID: error: NOTCHECK-MID-NOT: string occurred!
      // CHECK-NOTCHECK-MID-NEXT: warning:
      // CHECK-NOTCHECK-MID-NEXT: note: NOTCHECK-MID-NOT: pattern specified here
      // CHECK-NOTCHECK-MID-NEXT: IMPLICIT-CHECK-NOT: warning:
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["NOTCHECK-MID"], checkNot: ["warning:"], options: [.disableColors]) {
        // NOTCHECK-MID: error:
        print("error:")
        // NOTCHECK-MID: error:
        print("error:")
        print("warning:")
        // NOTCHECK-MID: error:
        print("error:")
        // NOTCHECK-MID: error:
        print("error:")
      })
    })
  }

  func testUndefinedVariablePattern() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-UNDEFINED-VAR-MSG"]) {
      // CHECK-UNDEFINED-VAR-MSG: note: uses undefined variable 'UNDEFINED'
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-UNDEFINED-VAR"], options: [.disableColors]) {
        // CHECK-UNDEFINED-VAR: [[UNDEFINED]]
        print("-")
      })
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testWhitespace", testWhitespace),
    ("testSame", testSame),
    ("testImplicitCheckNot", testImplicitCheckNot),
    ("testUndefinedVariablePattern", testUndefinedVariablePattern)
  ])
  #endif
}
