import FileCheck
import XCTest
import Foundation

class MultiPrefixSpec : XCTestCase {
  func testMultiplePrefixSubstr() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKER1", "CHECK"]) {
      // CHECKER1: fo{{o}}
      print("foo")
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECK", "CHECKER2"]) {
      // CHECKER2: fo{{o}}
      print("foo")
    })
  }

  func testMultiPrefixMixed() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["B1", "BOTH1"]) {
      // A1: {{a}}aaaaa
      // B1: {{b}}bbbb
      // BOTH: {{q}}qqqqq
      print([
        "aaaaaa",
        "bbbbb",
        "qqqqqq",
        "ccccc",
      ])
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["A2", "BOTH2"]) {
      // A2: {{a}}aaaaa
      // B2: {{b}}bbbb
      // BOTH2: {{q}}qqqqq
      print([
        "aaaaaa",
        "bbbbb",
        "qqqqqq",
        "ccccc",
        ])
    })
  }

  func testMultiplePrefixNoMatch() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["MULTI-PREFIX-ERR"]) {
      // MULTI-PREFIX-ERR: error: FOO: could not find a match for regex 'fo(o)' in input
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["FOO", "BAR"], options: [.disableColors]) {
        // _FOO not a valid check-line
        // FOO: fo{{o}}
        // BAR: ba{{r}}
        print(["fog", "bar"].joined(separator: "\n"))
      })
    })
  }

  func testMultiplePrefix2() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["BAZ", "BAZQUUX", "QUUXBAZ"], options: [.disableColors]) {
      // BAZ
      // BAZQUUX
      // BAZQUUX: this is the {{match}}
      // QUUXBAZ: this is {{another}}
      print("""
            this is the match
            this is another
            """)
    })
  }

  func testMultiplePrefixOverlap() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["AAAOVERLAP", "OVERLAP"]) {
      // OVERLAP: fo{{o}}
      // AAAOVERLAP: ba{{r}}
      // OVERLAP: buz{{z}}
      print("""
            foo
            bar
            buzz
            """)
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testMultiplePrefixSubstr", testMultiplePrefixSubstr),
    ("testMultiPrefixMixed", testMultiPrefixMixed),
    ("testMultiplePrefixNoMatch", testMultiplePrefixNoMatch),
    ("testMultiplePrefix2", testMultiplePrefix2),
    ("testMultiplePrefixOverlap", testMultiplePrefixOverlap),
  ])
  #endif
}

