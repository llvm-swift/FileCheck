import XCTest

@testable import FileCheckTests

#if !os(macOS)
XCTMain([
  DAGSpec.allTests,
  EmptySpec.allTests,
  FileCheckSpec.allTests,
  LabelSpec.allTests,
  LineCountSpec.allTests,
  MultiPrefixSpec.allTests,
  VariableRefSpec.allTests,
])
#endif
