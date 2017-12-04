import XCTest

@testable import FileCheckTests

#if !os(macOS)
XCTMain([
  DAGSpec.allTests,
  DefinesSpec.allTests,
  EmptySpec.allTests,
  FileCheckSpec.allTests,
  LabelSpec.allTests,
  LineCountSpec.allTests,
  MultiPrefixSpec.allTests,
  RegexScopeSpec.allTests,
  VariableRefSpec.allTests,
])
#endif
