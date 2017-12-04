import FileCheck
import XCTest
import Foundation

class DefinesSpec : XCTestCase {
  func testGlobalDefines() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["PASSDEF"], withGlobals: ["VALUE":"10"]) {
      // PASSDEF: Value = [[VALUE]]
      print("Value = 10")
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["FAILDEF-ERRMSG"]) {
      // FAILDEF-ERRMSG: error: {{.*}}: could not find a match for regex 'Value = 20' in input
      // FAILDEF-ERRMSG: note: with variable 'VALUE' equal to '20'
      // FAILDEF-ERRMSG: note: possible intended match here
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["FAILDEF"], withGlobals: ["VALUE":"20"], options: [.disableColors]) {
        // FAILDEF: Value = [[VALUE]]
        print("Value = 10")
      })
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testGlobalDefines", testGlobalDefines),
  ])
  #endif
}

