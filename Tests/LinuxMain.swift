import XCTest

@testable import FileCheckTests

#if !os(macOS)
XCTMain([
  FileCheckSpec.allTests,
  LineCountSpec.allTests,
])
#endif
