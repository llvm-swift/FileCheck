// THIS TEST IS LINE-COUNT DEPENDENT.  DO NOT RE-INDENT.
import FileCheck
import XCTest
import Foundation

class LineCountSpec : XCTestCase {
  func testLineCount() {
    let txt = [
      "9",
      "10 aaa",
      "11 bbb",
      "12 ccc",
      "13 CHECK-LINECOUNT: [[@LINE-3]] {{a}}aa",
      "14 CHECK-LINECOUNT: [[@LINE-3]] {{b}}bb",
      "15 CHECK-LINECOUNT: [[@LINE-3]] {{c}}cc",
      "16 foobar",
      "17 CHECK-LINECOUNT: [[@LINE-1]] {{foo}}bar",
      "18",
      "19 arst CHECK-LINECOUNT: [[@LINE]] {{a}}rst",
      "20",
      "21 BAD-CHECK-LINECOUNT: [[@LINE:cant-have-regex]]",
    ].joined(separator: "\n")

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-LINECOUNT"]) {
      print(txt)
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["BAD-CHECK-LINECOUNT"]) {
      print(txt)
    })
  }
  #if !os(macOS)
  static var allTests = testCase([
    ("testLineCount", testLineCount),
  ])
  #endif
}
