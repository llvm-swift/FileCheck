// THIS TEST IS LINE-COUNT DEPENDENT.  DO NOT RE-INDENT.
import FileCheck
import XCTest
import Foundation

final class LineCountSpec : XCTestCase {
  func testLineCount() {
    let txt = ((1...8).map({ "\($0)" }) + [
        "9 aaa"
      , "10 bbb"
      , "11 ccc", "", "", ""
      // 12 CHECK-LINECOUNT: [[@LINE-3]] {{a}}aa
      // 13 CHECK-LINECOUNT: [[@LINE-3]] {{b}}bb
      // 14 CHECK-LINECOUNT: [[@LINE-3]] {{c}}cc
      , "15 foobar", ""
      // 16 CHECK-LINECOUNT: [[@LINE-1]] {{foo}}bar
      , "17", "18 arst"
      // CHECK-LINECOUNT: [[@LINE]] {{a}}rst
      , "19"
      // 20 BAD-CHECK-LINECOUNT: [[@LINE:cant-have-regex]]
      // 21 CHECK-LINECOUNT-MISSPELL: [[@RINE]]
    ]).joined(separator: "\n")

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-LINECOUNT"]) {
      print(txt)
    })

    XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["BAD-CHECK-LINECOUNT"]) {
      print(txt)
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-LINECOUNT-MISSPELL-MSG"]) {
      // CHECK-LINECOUNT-MISSPELL-MSG: note: uses incorrect expression '@RINE'
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK-LINECOUNT-MISSPELL"], options: [.disableColors]) {
        print(txt)
      })
    })
  }
  #if !os(macOS)
  static var allTests = testCase([
    ("testLineCount", testLineCount),
  ])
  #endif
}
