import Foundation

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

/// `FileCheckOptions` enumerates supported FileCheck options that can be used
/// to modify the behavior of the checking routine.
public struct FileCheckOptions: OptionSet {
  public let rawValue: UInt64

  /// Convert from a value of `RawValue`, succeeding unconditionally.
  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  /// Do not treat all horizontal whitespace as equivalent.
  public static let strictWhitespace = FileCheckOptions(rawValue: 1 << 0)
  /// Allow the input file to be empty. This is useful when making checks that
  /// some error message does not occur, for example.
  public static let allowEmptyInput = FileCheckOptions(rawValue: 1 << 1)
  /// Require all positive matches to cover an entire input line.  Allows
  /// leading and trailing whitespace if `.strictWhitespace` is not also
  /// passed.
  public static let matchFullLines = FileCheckOptions(rawValue: 1 << 2)
  /// Disable colored diagnostics.
  public static let disableColors = FileCheckOptions(rawValue: 1 << 3)
}

/// `FileCheckFD` represents the standard output streams `FileCheck` is capable
/// of overriding to gather output.
public enum FileCheckFD {
  /// Standard output.
  case stdout
  /// Standard error.
  case stderr
  /// A custom output stream.
  case custom(fileno: Int32, ptr: UnsafeMutablePointer<FILE>)

  /// Retrieve the file descriptor for this output stream.
  var fileno : Int32 {
    switch self {
    case .stdout:
      return STDOUT_FILENO
    case .stderr:
      return STDERR_FILENO
    case let .custom(fileno: fd, ptr: _):
      return fd
    }
  }

  /// Retrieve the FILE pointer for this stream.
  var filePtr : UnsafeMutablePointer<FILE>! {
    switch self {
    case .stdout:
      #if os(Linux)
        return Glibc.stdout
      #else
        return Darwin.stdout
      #endif
    case .stderr:
      #if os(Linux)
        return Glibc.stderr
      #else
        return Darwin.stderr
      #endif
    case let .custom(fileno: _, ptr: ptr):
      return ptr
    }
  }
}

/// Reads from the given output stream and runs a file verification procedure
/// by comparing the output to a specified result.
///
/// FileCheck requires total access to whatever input stream is being used.  As
/// such it will override printing to said stream until the given block has
/// finished executing.
///
/// - parameter FD: The file descriptor to override and read from.
/// - parameter prefixes: Specifies one or more prefixes to match. By default
///   these patterns are prefixed with "CHECK".
/// - parameter checkNot: Specifies zero or more prefixes to implicitly reject
///   in the output stream.  This can be used to implement LLVM-verifier-like
///   checks.
/// - parameter file: The file to check against.  Defaults to the file that
///   contains the call to `fileCheckOutput`.
/// - parameter options: Optional arguments to modify the behavior of the check.
/// - parameter block: The block in which output will be emitted to the given
///   file descriptor.
///
/// - returns: Whether or not FileCheck succeeded in verifying the file.
public func fileCheckOutput(of FD : FileCheckFD = .stdout, withPrefixes prefixes : [String] = ["CHECK"], checkNot : [String] = [], against file : String = #file, options: FileCheckOptions = [], block : () -> ()) -> Bool {
  guard let validPrefixes = validateCheckPrefixes(prefixes) else {
    print("Supplied check-prefix is invalid! Prefixes must be unique and",
          "start with a letter and contain only alphanumeric characters,",
          "hyphens and underscores")
    return false
  }
  guard let prefixRE = try? NSRegularExpression(pattern: validPrefixes.sorted(by: >).joined(separator: "|")) else {
    print("Unable to combine check-prefix strings into a prefix regular ",
          "expression! This is likely a bug in FileCheck's verification of ",
          "the check-prefix strings. Regular expression parsing failed.")
    return false
  }

  let input = overrideFDAndCollectOutput(file: FD, of: block)
  if input.isEmpty {
    guard options.contains(.allowEmptyInput) else {
      print("FileCheck error: input from file descriptor \(FD) is empty.\n")
      return false
    }
    
    return true
  }

  guard let contents = try? String(contentsOfFile: file, encoding: .utf8) else {
    return false
  }
  let buf = contents.cString(using: .utf8)?.withUnsafeBufferPointer { buffer in
    return readCheckStrings(in: buffer, withPrefixes: validPrefixes, checkNot: checkNot, options: options, prefixRE)
  }
  guard let checkStrings = buf, !checkStrings.isEmpty else {
    return false
  }

  return check(input: input, against: checkStrings, options: options)
}

private func overrideFDAndCollectOutput(file : FileCheckFD, of block : () -> ()) -> String {
  fflush(file.filePtr)
  let oldFd = dup(file.fileno)

  let template = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("output.XXXXXX")
  return template.withUnsafeFileSystemRepresentation { buffer in
    guard let buffer = buffer else {
      return ""
    }

   	let newFd = mkstemp(UnsafeMutablePointer(mutating: buffer))
    guard newFd != -1 else {
      return ""
    }

    dup2(newFd, file.fileno)

    block()

    close(newFd)
    fflush(file.filePtr)


    dup2(oldFd, file.fileno)
    close(oldFd)

    let url = URL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeTo: nil)
    guard let s = try? String(contentsOf: url, encoding: .utf8) else {
      return ""
    }
    return s
  }
}

private func validateCheckPrefixes(_ prefixes : [String]) -> [String]? {
  let validator = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_-]*$")

  var prefixUniquer = Set<String>()
  for prefix in prefixes {
    // Reject empty prefixes.
    guard !prefix.isEmpty && !prefixUniquer.contains(prefix) else {
      return nil
    }
    prefixUniquer.insert(prefix)

    let range = NSRange(
      location: 0,
      length: prefix.distance(from: prefix.startIndex, to: prefix.endIndex)
    )
    if validator.matches(in: prefix, range: range).isEmpty {
      return nil
    }
  }

  return [String](prefixUniquer)
}

extension CChar {
  fileprivate var isPartOfWord : Bool {
    return isalnum(Int32(self)) != 0 || self == ("-" as Character).utf8CodePoint || self == ("_" as Character).utf8CodePoint
  }
}

extension Character {
  var utf8CodePoint : CChar {
    return String(self).cString(using: .utf8)!.first!
  }

  fileprivate var isPartOfWord : Bool {
    let utf8Value = self.utf8CodePoint
    return isalnum(Int32(utf8Value)) != 0 || self == "-" || self == "_"
  }
}

private func findCheckType(in buf : UnsafeBufferPointer<CChar>, with prefix : String) -> CheckType {
  let nextChar = buf[prefix.utf8.count]

  // Verify that the : is present after the prefix.
  if nextChar == (":" as Character).utf8CodePoint {
    return .plain
  }
  if nextChar != ("-" as Character).utf8CodePoint {
    return .none
  }

  let rest = String(
    bytesNoCopy: UnsafeMutableRawPointer(
      mutating: buf.baseAddress!.advanced(by: prefix.utf8.count + 1)
    ),
    length: buf.count - (prefix.utf8.count + 1),
    encoding: .utf8,
    freeWhenDone: false
  )!
  if rest.hasPrefix("NEXT:") {
    return .next
  }

  if rest.hasPrefix("SAME:") {
    return .same
  }

  if rest.hasPrefix("NOT:") {
    return .not
  }

  if rest.hasPrefix("DAG:") {
    return .dag
  }

  if rest.hasPrefix("LABEL:") {
    return .label
  }

  // You can't combine -NOT with another suffix.
  let badNotPrefixes = [
    "DAG-NOT:",
    "NOT-DAG:",
    "NEXT-NOT:",
    "NOT-NEXT:",
    "SAME-NOT:",
    "NOT-SAME:",
  ]

  if badNotPrefixes.reduce(false, { (acc, s) in acc || rest.hasPrefix(s) }) {
    return .badNot
  }

  return .none
}

extension UnsafeBufferPointer {
  fileprivate func substr(_ start : Int, _ size : Int) -> UnsafeBufferPointer<Element> {
    return UnsafeBufferPointer<Element>(start: self.baseAddress!.advanced(by: start), count: size)
  }

  fileprivate func dropFront(_ n : Int) -> UnsafeBufferPointer<Element> {
    precondition(n < self.count)
    return UnsafeBufferPointer<Element>(start: self.baseAddress!.advanced(by: n), count: self.count - n)
  }
}

extension CheckLocation {
  var message : String {
    switch self {
    case let .inBuffer(ptr, buf):
      var startPtr = ptr
      while startPtr != buf.baseAddress! && startPtr.predecessor().pointee != ("\n" as Character).utf8CodePoint {
        startPtr = startPtr.predecessor()
      }

      var endPtr = ptr
      while endPtr != buf.baseAddress!.advanced(by: buf.endIndex) && endPtr.successor().pointee != ("\n" as Character).utf8CodePoint {
        endPtr = endPtr.successor()
      }
      // One more for good measure.
      if endPtr != buf.baseAddress!.advanced(by: buf.endIndex) {
        endPtr = endPtr.successor()
      }
      return substring(in: buf, with: NSMakeRange(buf.baseAddress!.distance(to: startPtr), startPtr.distance(to: endPtr)))
    case let .string(s):
      return s
    }
  }
}

private func substring(in buffer : UnsafeBufferPointer<CChar>, with range : NSRange) -> String {
  precondition(range.location + range.length <= buffer.count)
  let ptr = buffer.substr(range.location, range.length)
  return String(bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr.baseAddress!), length: range.length, encoding: .utf8, freeWhenDone: false) ?? ""
}

private func findFirstMatch(in inbuffer : UnsafeBufferPointer<CChar>, among prefixes : [String], with RE : NSRegularExpression, startingAt startLine: Int) -> (String, CheckType, Int, UnsafeBufferPointer<CChar>) {
  var lineNumber = startLine
  var buffer = inbuffer

  while !buffer.isEmpty {
    let str = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer.baseAddress!), length: buffer.count, encoding: .utf8, freeWhenDone: false)!
    let match = RE.firstMatch(in: str, range: NSRange(location: 0, length: str.distance(from: str.startIndex, to: str.endIndex)))
    guard let prefix = match else {
      return ("", .none, lineNumber, buffer)
    }
    let skippedPrefix = substring(in: buffer, with: NSMakeRange(0, prefix.range.location))
    let prefixStr = String(str[
      Range(
        uncheckedBounds: (
          str.index(str.startIndex, offsetBy: prefix.range.location),
          str.index(str.startIndex, offsetBy: NSMaxRange(prefix.range))
        )
      )
    ])

    // HACK: Conversion between the buffer and `String` causes index
    // mismatches when searching for strings.  We're instead going to do
    // something terribly inefficient here: Use the regular expression to
    // look for check prefixes, then use Foundation's Data to find their
    // actual locations in the buffer.
    let bd = Data(buffer: buffer)
    let range = bd.range(of: prefixStr.data(using: .utf8)!)!
    buffer = buffer.dropFront(range.lowerBound)
    lineNumber += (skippedPrefix.characters.filter({ c in c == "\n" }) as [Character]).count
    // Check that the matched prefix isn't a suffix of some other check-like
    // word.
    // FIXME: This is a very ad-hoc check. it would be better handled in some
    // other way. Among other things it seems hard to distinguish between
    // intentional and unintentional uses of this feature.
    if skippedPrefix.isEmpty || !skippedPrefix.characters.last!.isPartOfWord {
      // Now extract the type.
      let checkTy = findCheckType(in: buffer, with: prefixStr)


      // If we've found a valid check type for this prefix, we're done.
      if checkTy != .none {
        return (prefixStr, checkTy, lineNumber, buffer)
      }
    }
    // If we didn't successfully find a prefix, we need to skip this invalid
    // prefix and continue scanning. We directly skip the prefix that was
    // matched and any additional parts of that check-like word.
    // From the given position, find the next character after the word.
    var loc = prefix.range.length
    while loc < buffer.count && buffer[loc].isPartOfWord {
      loc += 1
    }
    buffer = buffer.dropFront(loc)
  }

  return ("", .none, lineNumber, buffer)
}

private func readCheckStrings(in buf : UnsafeBufferPointer<CChar>, withPrefixes prefixes : [String], checkNot : [String], options: FileCheckOptions, _ RE : NSRegularExpression) -> [CheckString] {
  // Keeps track of the line on which CheckPrefix instances are found.
  var lineNumber = 1
  var implicitNegativeChecks = [Pattern]()
  for notPattern in checkNot {
    if notPattern.isEmpty {
      continue
    }

    notPattern.utf8CString.withUnsafeBufferPointer { buf in
      let patBuf = UnsafeBufferPointer<CChar>(start: buf.baseAddress, count: buf.count - 1)
      let pat = Pattern(checking: .not, in: buf, pattern: patBuf, withPrefix: "IMPLICIT-CHECK", at: 0, options: options)!
      // Compute the message from this buffer now for diagnostics later.
      let msg = CheckLocation.inBuffer(buf.baseAddress!, buf).message
      implicitNegativeChecks.append(Pattern(copying: pat, at: .string("IMPLICIT-CHECK-NOT: " + msg)))
    }
  }
  var dagNotMatches = implicitNegativeChecks
  var contents = [CheckString]()

  var buffer = buf
  while true {
    // See if a prefix occurs in the memory buffer.
    let (usedPrefix, checkTy, ln, newBuffer) = findFirstMatch(in: buffer, among: prefixes, with: RE, startingAt: lineNumber)
    if usedPrefix.isEmpty {
      break
    }
    lineNumber = ln

    // Skip the buffer to the end.
    buffer = newBuffer.dropFront(usedPrefix.utf8.count + checkTy.prefixSize)

    // Complain about useful-looking but unsupported suffixes.
    if checkTy == .badNot {
      let loc = CheckLocation.inBuffer(buffer.baseAddress!, buf)
      diagnose(.error, at: loc, with: "unsupported -NOT combo on prefix '\(usedPrefix)'", options: options)
      return []
    }

    // Okay, we found the prefix, yay. Remember the rest of the line, but
    // ignore leading whitespace.
    if !options.contains(.strictWhitespace) || !options.contains(.matchFullLines) {
      guard let idx = buffer.index(where: { c in c != (" " as Character).utf8CodePoint && c != ("\t" as Character).utf8CodePoint }) else {
        return []
      }
      buffer = buffer.dropFront(idx)
    }

    // Scan ahead to the end of line.
    let EOL : Int = buffer.index(of: ("\n" as Character).utf8CodePoint) ?? buffer.index(of: ("\r" as Character).utf8CodePoint)!

    // Remember the location of the start of the pattern, for diagnostics.
    let patternLoc = CheckLocation.inBuffer(buffer.baseAddress!, buf)

    // Parse the pattern.
    let subBuffer = UnsafeBufferPointer<CChar>(start: buffer.baseAddress, count: EOL)
    guard let pat = Pattern(checking: checkTy, in: buf, pattern: subBuffer, withPrefix: usedPrefix, at: lineNumber, options: options) else {
      return []
    }

    // Verify that CHECK-LABEL lines do not define or use variables
    if (checkTy == .label) && pat.hasVariable {
      diagnose(.error, at: patternLoc, with: "found '\(usedPrefix)-LABEL:' with variable definition or use", options: options)
      return []
    }

    // Verify that CHECK-NEXT lines have at least one CHECK line before them.
    if (checkTy == .next || checkTy == .same) && contents.isEmpty {
      let type = (checkTy == .next) ? "NEXT" : "SAME"
      let loc = CheckLocation.inBuffer(buffer.baseAddress!, buf)
      diagnose(.error, at: loc, with: "found '\(usedPrefix)-\(type)' without previous '\(usedPrefix): line", options: options)
      return []
    }

    buffer = UnsafeBufferPointer<CChar>(
      start: buffer.baseAddress!.advanced(by: EOL),
      count: buffer.count - EOL
    )

    // Handle CHECK-DAG/-NOT.
    if checkTy == .dag || checkTy == .not {
      dagNotMatches.append(pat)
      continue
    }

    // Okay, add the string we captured to the output vector and move on.
    let cs = CheckString(
      pattern: pat,
      prefix: usedPrefix,
      location: .string(patternLoc.message),
      dagNotStrings: dagNotMatches
    )
    contents.append(cs)
    dagNotMatches = implicitNegativeChecks
  }

  // Add an EOF pattern for any trailing CHECK-DAG/-NOTs, and use the first
  // prefix as a filler for the error message.
  if !dagNotMatches.isEmpty {
    let cs = CheckString(
      pattern: Pattern(withType: .endOfFile),
      prefix: prefixes.first!,
      location: dagNotMatches.last!.patternLoc,
      dagNotStrings: dagNotMatches
    )
    contents.append(cs)
  }

  if contents.isEmpty {
    print("error: no check strings found with prefix\(contents.count == 1 ? " " : "es ")")
    for prefix in prefixes {
      print("\(prefix):")
    }
    return []
  }

  return contents
}

/// Check the input to FileCheck provided in the buffer against the check
/// strings read from the check file.
///
/// Returns `false` if the input fails to satisfy the checks.
private func check(input b : String, against checkStrings : [CheckString], options: FileCheckOptions) -> Bool {
  var buffer = Substring(b)
  var failedChecks = false

  // This holds all the current filecheck variables.
  var variableTable = [String:String]()

  var i = 0
  var j = 0
  while true {
    var checkRegion : Substring
    if j == checkStrings.count {
      checkRegion = buffer
    } else {
      let checkStr = checkStrings[j]
      guard checkStr.pattern.type == .label else {
        j += 1
        continue
      }

      // Scan to next CHECK-LABEL match, ignoring CHECK-NOT and CHECK-DAG
      guard let (range, mutVariableTable) = checkStr.check(String(buffer), true, variableTable, options) else {
        // Immediately bail if CHECK-LABEL fails, nothing else we can do.
        return false
      }

      variableTable = mutVariableTable
      checkRegion = buffer[..<buffer.index(buffer.startIndex, offsetBy: NSMaxRange(range))]
      buffer = buffer[buffer.index(buffer.startIndex, offsetBy: NSMaxRange(range))...]
      j += 1
    }

    while i != j {
      defer { i += 1 }

      // Check each string within the scanned region, including a second check
      // of any final CHECK-LABEL (to verify CHECK-NOT and CHECK-DAG)
      guard let (range, mutVarTable) = checkStrings[i].check(String(checkRegion), false, variableTable, options) else {
        failedChecks = true
        i = j-1
        break
      }
      variableTable = mutVarTable
      checkRegion = checkRegion[checkRegion.index(checkRegion.startIndex, offsetBy: NSMaxRange(range))...]
    }
    
    if j == checkStrings.count {
      break
    }
  }
  
  // Success if no checks failed.
  return !failedChecks
}
