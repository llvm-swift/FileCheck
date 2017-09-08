import FileCheck
import XCTest
import Foundation

#if swift(>=4)
class LabelSpec : XCTestCase {
  func testLabels() {
    let output = {
      print("""
            label0:
            a
            b

            label1:
            b
            c

            label2:
            a
            c
            """)
    }
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
}
#endif
