import FileCheck
import XCTest
import Foundation

class RegexScopeSpec : XCTestCase {
  func testRegexScope() {
    let block = { () -> () in
      // CHECK: [[LOCAL:loc.*]]
      // CHECK: [[$GLOBAL:glo.*]]
      print("""
            local
            global
            """)
      // CHECK: [[LOCAL]]2
      // CHECK: [[$GLOBAL]]2
      print("""
            local2
            global2
            """)
      // CHECK-LABEL: barrier
      print("""
            barrier:
            """)
      // LOCAL: [[LOCAL]]3
      // GLOBAL: [[$GLOBAL]]3
      print("""
            local3
            global3
            """)
    }
    XCTAssert(fileCheckOutput(of: .stdout, block: block))
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK", "GLOBAL"], block: block))
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK", "LOCAL"], block: block))
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK", "GLOBAL"], options: [.scopedVariables], block: block))
    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK", "LOCAL"], options: [.scopedVariables], block: block))
  }
  #if !os(macOS)
  static var allTests = testCase([
    ("testRegexScope", testRegexScope),
  ])
  #endif
}

