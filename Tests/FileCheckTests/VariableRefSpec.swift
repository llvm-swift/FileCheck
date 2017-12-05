import FileCheck
import XCTest
import Foundation

class VariableRefSpec : XCTestCase {
  func testSameLineVarRef() {
    XCTAssert(fileCheckOutput(of: .stdout) {
      // CHECK: op1 [[REG:r[0-9]+]], {{r[0-9]+}}, [[REG]]
      print("op1 r1, r2, r1")
      // CHECK: op3 [[REG1:r[0-9]+]], [[REG2:r[0-9]+]], [[REG1]], [[REG2]]
      print("op3 r1, r2, r1, r2")
      // Test that parens inside the regex don't confuse FileCheck
      // CHECK: {{([a-z]+[0-9])+}} [[REG:g[0-9]+]], {{g[0-9]+}}, [[REG]]
      print("op4 g1, g2, g1")
    })
  }
  
  #if !os(macOS)
  static var allTests = testCase([
    ("testSameLineVarRef", testSameLineVarRef),
  ])
  #endif
}


