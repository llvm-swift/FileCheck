import FileCheck
import XCTest
import Foundation

final class EmptySpec : XCTestCase {
  func testEmptyError() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["EMPTY-ERR"]) {
      // EMPTY-ERR: FileCheck error: input from file descriptor stdout is empty.
      XCTAssertFalse(fileCheckOutput(options: [.disableColors]) {})
    })
  }

  func testAllowEmpty() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["ALLOW-EMPTY-ERR"], options: [.allowEmptyInput]) {
      // ALLOW-EMPTY-ERR-NOT: FileCheck error: input from file descriptor stdout is empty.
      XCTAssert(fileCheckOutput(options: [.allowEmptyInput]) {})
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testAllowEmpty", testAllowEmpty),
    ("testEmptyError", testEmptyError),
  ])
  #endif
}
