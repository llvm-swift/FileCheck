import FileCheck
import XCTest
import Foundation

class LabelSpec : XCTestCase {
  let output = {
    print([
      "label0:",
      "a",
      "b",
      "",
      "label1:",
      "b",
      "c",
      "",
      "label2:",
      "a",
      "c",
    ].joined(separator: "\n"))
  }
  
  func testLabels() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKOK"]) {
      // CHECKOK-LABEL: {{^}}label0:
      // CHECKOK: {{^}}a
      // CHECKOK: {{^}}b

      // CHECKOK-LABEL: {{^}}label1:
      // CHECKOK: {{^}}b
      // CHECKOK: {{^}}c

      // CHECKOK-LABEL: {{^}}label2:
      // CHECKOK: {{^}}a
      // CHECKOK: {{^}}c
      output()
    })
  }

  func labelFail() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKERROR"]) {
      // CHECKERROR: error: CHECKFAIL: could not find a match for regex '(^)c' in input
      //
      // CHECKERROR: error: CHECKFAIL: could not find a match for regex '(^)a' in input
      //
      // CHECKERROR: error: CHECKFAIL: could not find a match for regex '(^)b' in input
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKFAIL"], options: [.disableColors]) {
        // CHECKFAIL-LABEL: {{^}}label0:
        // CHECKFAIL: {{^}}a
        // CHECKFAIL: {{^}}b
        // CHECKFAIL: {{^}}c
        //
        // CHECKFAIL-LABEL: {{^}}label1:
        // CHECKFAIL: {{^}}a
        // CHECKFAIL: {{^}}b
        // CHECKFAIL: {{^}}c
        //
        // CHECKFAIL-LABEL: {{^}}label2:
        // CHECKFAIL: {{^}}a
        // CHECKFAIL: {{^}}b
        // CHECKFAIL: {{^}}c
        output()
      })
    })
  }
}
