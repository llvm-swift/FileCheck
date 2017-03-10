import XCTest

@testable import LLVMTests

#if !os(macOS)
XCTMain([
  FileCheckSpec.allTests,
])
#endif
