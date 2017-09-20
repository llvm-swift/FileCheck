import FileCheck
import XCTest
import Foundation

class LabelSpec : XCTestCase {
  let outputABC = {
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
      outputABC()
    })
  }

  func testLabelFail() {
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
        outputABC()
      })
    })
  }

  func testLabelDAG() {
    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKLABELDAG-ERROR"]) {
      //    CHECKLABELDAG-ERROR: error: CHECKLABELDAG: could not find a match for regex '(^)foo' in input
      XCTAssertFalse(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKLABELDAG"], options: [.disableColors]) {
        // CHECKLABELDAG-LABEL: {{^}}bar
        // CHECKLABELDAG-DAG: {{^}}foo
        // CHECKLABELDAG-LABEL: {{^}}zed
        print(["bar", "zed"].joined(separator: "\n"))
      })
    })

    XCTAssert(fileCheckOutput(of: .stdout, withPrefixes: ["CHECKLABELDAGCAPTURE"], options: [.disableColors]) {
      // CHECKLABELDAGCAPTURE-LABEL: {{^}}bar
      // CHECKLABELDAGCAPTURE: {{^}}[[FOO:foo]]
      // CHECKLABELDAGCAPTURE-DAG: {{^}}[[FOO]]
      // CHECKLABELDAGCAPTURE-LABEL: {{^}}zed
      print(["bar", "foo", "foo", "zed"].joined(separator: "\n"))
    })
  }

  #if !os(macOS)
  static var allTests = testCase([
    ("testLabels", testLabels),
    ("testLabelFail", testLabelFail),
    ("testLabelDAG", testLabelDAG),
  ])
  #endif
}
