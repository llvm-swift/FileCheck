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

  func testNearestPattern() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-NEAREST-PATTERN-MSG"]) {
      // CHECK-NEAREST-PATTERN-MSG: error: {{.*}}: could not find 'Once more into the beach' (with regex '') in input
      // CHECK-NEAREST-PATTERN-MSG-NEXT: // {{.*}}: Once more into the beach
      // CHECK-NEAREST-PATTERN-MSG-NEXT: note: possible intended match here
      // CHECK-NEAREST-PATTERN-MSG-NEXT: Once more into the breach
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-NEAREST-PATTERN"], options: [.disableColors]) {
        // CHECK-NEAREST-PATTERN: Once more into the beach
        print("Once more into the breach")
      })
    })
  }

  func testNotDiagInfo() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["NOTDIAGINFO-TEXT"]) {
      // NOTDIAGINFO-TEXT: error: NOTDIAGINFO-NOT: string occurred!
      // NOTDIAGINFO-TEXT-NEXT: test
      // NOTDIAGINFO-TEXT-NEXT: note: NOTDIAGINFO-NOT: pattern specified here
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["NOTDIAGINFO"], options: .disableColors) {
        // NOTDIAGINFO-NOT: test
        print("test")
      })
    })
  }

  func testNonExistentPrefix() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-NONEXISTENT-PREFIX-ERR"]) {
      // CHECK-NONEXISTENT-PREFIX-ERR: error: no check strings found with prefixes
      // CHECK-NONEXISTENT-PREFIX-ERR-NEXT: CHECK-NONEXISTENT-PREFIX{{:}}
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-NONEXISTENT-PREFIX"], options: [.disableColors]) {
        // A-DIFFERENT-PREFIX: foobar
        print("foobar")
      })
    })
  }

  func testInvalidCheckPrefix() {
    // BAD_PREFIX: Supplied check-prefix is invalid! Prefixes must be unique and start with a letter and contain only alphanumeric characters, hyphens and underscores
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["BAD_PREFIX"]) {
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["A!"]) { })
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["A1a-B_c"]) {
      // A1a-B_c: foobar
      print("foobar")
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["BAD_PREFIX"]) {
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["REPEAT", "REPEAT"]) { })
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["BAD_PREFIX"]) {
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["VALID", "A!"]) { })
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["BAD_PREFIX"]) {
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: [" "]) { })
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testWhitespace", testWhitespace),
    ("testSame", testSame),
    ("testCheckDAG", testCheckDAG),
    ("testImplicitCheckNot", testImplicitCheckNot),
    ("testUndefinedVariablePattern", testUndefinedVariablePattern),
    ("testNearestPattern", testNearestPattern),
    ("testNotDiagInfo", testNotDiagInfo),
    ("testNonExistentPrefix", testNonExistentPrefix),
    ("testInvalidCheckPrefix", testInvalidCheckPrefix),
  ])
  #endif
}
