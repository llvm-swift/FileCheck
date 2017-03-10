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

  #if !os(macOS)
  static var allTests = testCase([
    ("testWhitespace", testWhitespace),
    ("testSame", testSame),
    ("testImplicitCheckNot", testImplicitCheckNot),
  ])
  #endif
}
