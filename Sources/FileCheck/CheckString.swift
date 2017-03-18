//
//  CheckString.swift
//  FileCheck
//
//  Created by Robert Widmann on 3/9/17.
//
//

import Foundation

enum CheckType {
  case none
  case plain
  case next
  case same
  case not
  case dag
  case label
  case badNot

  /// MatchEOF - When set, this pattern only matches the end of file. This is
  /// used for trailing CHECK-NOTs.
  case EOF

  // Get the size of the prefix extension.
  var size : Int {
    switch (self) {
    case .none:
      return 0
    case .badNot:
      return 0
    case .plain:
      return ":".utf8.count
    case .next:
      return "-NEXT:".utf8.count
    case .same:
      return "-SAME:".utf8.count
    case .not:
      return "-NOT:".utf8.count
    case .dag:
      return "-DAG:".utf8.count
    case .label:
      return "-LABEL:".utf8.count
    case .EOF:
      fatalError("Should not be using EOF size")
    }
  }
}

/// CheckString - This is a check that we found in the input file.
struct CheckString {
  /// The pattern to match.
  let pattern : Pattern

  /// Which prefix name this check matched.
  let prefix : String

  /// The location in the match file that the check string was specified.
  let loc : CheckLoc

  /// These are all of the strings that are disallowed from occurring between
  /// this match string and the previous one (or start of file).
  var dagNotStrings : Array<Pattern>

  /// Match check string and its "not strings" and/or "dag strings".
  func check(_ buffer : String, _ isLabelScanMode : Bool,  _ variableTable : [String:String], _ options: FileCheckOptions) -> (NSRange, [String:String])? {
    // This condition is true when we are scanning forward to find CHECK-LABEL
    // bounds we have not processed variable definitions within the bounded block
    // yet so cannot handle any final CHECK-DAG yet this is handled when going
    // over the block again (including the last CHECK-LABEL) in normal mode.
    let lastPos : Int
    let notStrings : [Pattern]
    let initialTable : [String:String]
    if !isLabelScanMode {
      // Match "dag strings" (with mixed "not strings" if any).
      guard let (lp, ns, vt) = self.checkDAG(buffer, variableTable, options) else {
        return nil
      }
      lastPos = lp
      notStrings = ns
      initialTable = vt
    } else {
      lastPos = 0
      notStrings = []
      initialTable = variableTable
    }

    // Match itself from the last position after matching CHECK-DAG.
    let matchBuffer = buffer.substring(from: buffer.index(buffer.startIndex, offsetBy: lastPos))
    guard let (range, mutVariableTable) = self.pattern.match(matchBuffer, initialTable) else {
      if let rtm = self.pattern.computeRegexToMatch(variableTable) {
        if !self.pattern.fixedString.isEmpty {
          diagnose(.error,
                   at: self.loc,
                   with: self.prefix + ": could not find '\(self.pattern.fixedString)' (with regex '\(rtm)') in input",
            options: options
          )
        } else {
          diagnose(.error,
                   at: self.loc,
                   with: self.prefix + ": could not find a match for regex '\(rtm)' in input",
            options: options
          )
        }
      } else {
        diagnose(.error,
                 at: self.loc,
                 with: self.prefix + ": could not find '\(self.pattern.fixedString)' in input",
          options: options
        )
      }
      return nil
    }
    let (matchPos, matchLen) = (range.location, range.length)

    // Similar to the above, in "label-scan mode" we can't yet handle CHECK-NEXT
    // or CHECK-NOT
    let finalTable : [String:String]
    if !isLabelScanMode {
      let startIdx = buffer.index(buffer.startIndex, offsetBy: lastPos)
      let skippedRegion = buffer.substring(
        with: Range<String.Index>(
          uncheckedBounds: (
            startIdx,
            buffer.index(startIdx, offsetBy: matchPos)
          )
        )
      )
      let rest = buffer.substring(from: buffer.index(buffer.startIndex, offsetBy: matchPos))

      // If this check is a "CHECK-NEXT", verify that the previous match was on
      // the previous line (i.e. that there is one newline between them).
      if self.checkNext(skippedRegion, rest, options) {
        return nil
      }

      // If this check is a "CHECK-SAME", verify that the previous match was on
      // the same line (i.e. that there is no newline between them).
      if self.checkSame(skippedRegion, rest, options) {
        return nil
      }

      // If this match had "not strings", verify that they don't exist in the
      // skipped region.
      let (cond, variableTable) = self.checkNot(skippedRegion, notStrings, mutVariableTable, options)
      finalTable = variableTable
      if cond {
        return nil
      }
    } else {
      finalTable = mutVariableTable
    }

    return (NSRange(location: lastPos + matchPos, length: matchLen), finalTable)
  }

  /// Verify there is no newline in the given buffer.
  private func checkSame(_ buffer : String, _ rest : String, _ options: FileCheckOptions) -> Bool {
    if self.pattern.type != .same {
      return false
    }

    // Count the number of newlines between the previous match and this one.
    //	  assert(Buffer.data() !=
    //				 SM.getMemoryBuffer(SM.FindBufferContainingLoc(
    //										SMLoc::getFromPointer(Buffer.data())))
    //					 ->getBufferStart() &&
    //			 "CHECK-SAME can't be the first check in a file")

    let (numNewLines, _ /*firstNewLine*/) = countNumNewlinesBetween(buffer)
    if numNewLines != 0 {
      diagnose(.error,
               at: self.loc,
               with: self.prefix + "-SAME: is not on the same line as the previous match",
               options: options
      )
      rest.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!, buf)
        diagnose(.note, at: loc, with: "'next' match was here", options: options)
      }
      buffer.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!, buf)
        diagnose(.note, at: loc, with: "previous match ended here", options: options)
      }
      return true
    }

    return false
  }

  /// Verify there is a single line in the given buffer.
  private func checkNext(_ buffer : String, _ rest : String, _ options: FileCheckOptions) -> Bool {
    if self.pattern.type != .next {
      return false
    }

    // Count the number of newlines between the previous match and this one.
    //	  assert(Buffer.data() !=
    //				 SM.getMemoryBuffer(SM.FindBufferContainingLoc(
    //										SMLoc::getFromPointer(Buffer.data())))
    //					 ->getBufferStart(), "CHECK-NEXT can't be the first check in a file")

    let (numNewLines, firstNewLine) = countNumNewlinesBetween(buffer)
    if numNewLines == 0 {
      diagnose(.error, at: self.loc, with: prefix + "-NEXT: is on the same line as previous match", options: options)
      rest.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!, buf)
        diagnose(.note, at: loc, with: "'next' match was here", options: options)
      }
      buffer.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!, buf)
        diagnose(.note, at: loc, with: "previous match ended here", options: options)
      }
      return true
    }

    if numNewLines != 1 {
      diagnose(.error, at: self.loc, with: prefix + "-NEXT: is not on the line after the previous match", options: options)
      rest.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!, buf)
        diagnose(.note, at: loc, with: "'next' match was here", options: options)
      }
      buffer.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!, buf)
        diagnose(.note, at: loc, with: "previous match ended here", options: options)
        if let fnl = firstNewLine {
          let noteLoc = CheckLoc.inBuffer(buf.baseAddress!.advanced(by: buffer.distance(from: buffer.startIndex, to: fnl)), buf)
          diagnose(.note, at: noteLoc, with: "non-matching line after previous match is here", options: options)
        }
      }
      return true
    }

    return false
  }

  /// Verify there's no "not strings" in the given buffer.
  private func checkNot(_ buffer : String, _ notStrings : [Pattern], _ variableTable : [String:String], _ options: FileCheckOptions) -> (Bool, [String:String]) {
    for pat in notStrings {
      assert(pat.type == .not, "Expect CHECK-NOT!")

      guard let (range, variableTable) = pat.match(buffer, variableTable) else {
        continue
      }
      buffer.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
        let loc = CheckLoc.inBuffer(buf.baseAddress!.advanced(by: range.location), buf)
        diagnose(.error, at: loc, with: self.prefix + "-NOT: string occurred!", options: options)
      }
      diagnose(.note, at: pat.patternLoc, with: self.prefix + "-NOT: pattern specified here", options: options)
      return (true, variableTable)
    }

    return (false, variableTable)
  }

  /// Match "dag strings" and their mixed "not strings".
  func checkDAG(_ buffer : String, _ variableTable : [String:String], _ options: FileCheckOptions) -> (Int, [Pattern], [String:String])? {
    var notStrings = [Pattern]()
    if self.dagNotStrings.isEmpty {
      return (0, notStrings, variableTable)
    }

    var lastPos = 0
    var startPos = lastPos

    var finalTable : [String:String] = variableTable
    for pattern in self.dagNotStrings {
      assert((pattern.type == .dag || pattern.type == .not), "Invalid CHECK-DAG or CHECK-NOT!")

      if pattern.type == .not {
        notStrings.append(pattern)
        continue
      }

      assert((pattern.type == .dag), "Expect CHECK-DAG!")

      // CHECK-DAG always matches from the start.
      let matchBuffer = buffer.substring(from: buffer.index(buffer.startIndex, offsetBy: startPos))
      // With a group of CHECK-DAGs, a single mismatching means the match on
      // that group of CHECK-DAGs fails immediately.
      guard let (range, variableTable) = pattern.match(matchBuffer, finalTable) else {
        //				PrintCheckFailed(SM, Pat.getLoc(), Pat, MatchBuffer, VariableTable)
        return nil
      }
      finalTable = variableTable

      // Re-calc it as the offset relative to the start of the original string.
      let matchPos = range.location + startPos
      if !notStrings.isEmpty {
        if matchPos < lastPos {
          // Reordered?
          buffer.cString(using: .utf8)?.withUnsafeBufferPointer { buf in
            let loc1 = CheckLoc.inBuffer(buf.baseAddress!.advanced(by: matchPos), buf)
            diagnose(.error, at: loc1, with: prefix + "-DAG: found a match of CHECK-DAG reordering across a CHECK-NOT", options: options)
            let loc2 = CheckLoc.inBuffer(buf.baseAddress!.advanced(by: lastPos), buf)
            diagnose(.note, at: loc2, with: prefix + "-DAG: the farthest match of CHECK-DAG is found here", options: options)
          }
          diagnose(.note, at: notStrings[0].patternLoc, with: prefix + "-NOT: the crossed pattern specified here", options: options)
          diagnose(.note, at: pattern.patternLoc, with: prefix + "-DAG: the reordered pattern specified here", options: options)
          return nil
        }
        // All subsequent CHECK-DAGs should be matched from the farthest
        // position of all precedent CHECK-DAGs (including this one.)
        startPos = lastPos
        // If there's CHECK-NOTs between two CHECK-DAGs or from CHECK to
        // CHECK-DAG, verify that there's no 'not' strings occurred in that
        // region.
        let skippedRegion = buffer.substring(
          with: Range<String.Index>(
            uncheckedBounds: (
              buffer.index(buffer.startIndex, offsetBy: lastPos),
              buffer.index(buffer.startIndex, offsetBy: matchPos)
            )
          )
        )
        let (cond, mutVarTable) = self.checkNot(skippedRegion, notStrings, finalTable, options)
        if cond {
          return nil
        }
        finalTable = mutVarTable
        // Clear "not strings".
        notStrings.removeAll()
      }

      // Update the last position with CHECK-DAG matches.
      lastPos = max(matchPos + range.length, lastPos)
    }
    
    return (lastPos, notStrings, finalTable)
  }
}
