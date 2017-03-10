//
//  Pattern.swift
//  FileCheck
//
//  Created by Robert Widmann on 3/9/17.
//
//

import Foundation

final class Pattern {
  let patternLoc : CheckLoc

  let type : CheckType

  /// If non-empty, this pattern is a fixed string match with the specified
  /// fixed string.
  let fixedString : String

  /// If non-empty, this is a regex pattern.
  var regExPattern : String = ""

  /// Contains the number of line this pattern is in.
  let lineNumber : Int

  /// Entries in this vector map to uses of a variable in the pattern, e.g.
  /// "foo[[bar]]baz".  In this case, the regExPattern will contain "foobaz"
  /// and we'll get an entry in this vector that tells us to insert the value
  /// of bar at offset 3.
  var variableUses : Array<(String, Int)> = []

  /// Maps definitions of variables to their parenthesized capture numbers.
  /// E.g. for the pattern "foo[[bar:.*]]baz", VariableDefs will map "bar" to 1.
  var variableDefs : Dictionary<String, Int> = [:]

  let options : FileCheckOptions

  var hasVariable : Bool {
    return !(variableUses.isEmpty && self.variableDefs.isEmpty)
  }

  init(copying other: Pattern, at loc: CheckLoc) {
    self.patternLoc = loc
    self.type = other.type
    self.fixedString = other.fixedString
    self.regExPattern = other.regExPattern
    self.lineNumber = other.lineNumber
    self.variableUses = other.variableUses
    self.variableDefs = other.variableDefs
    self.options = other.options
  }

  init(withType ty: CheckType) {
    self.type = ty
    self.patternLoc = .string("")
    self.lineNumber = -1
    self.fixedString = ""
    self.options = []
  }

  init?(checking ty : CheckType, in buf : UnsafeBufferPointer<CChar>, pattern : UnsafeBufferPointer<CChar>, withPrefix prefix : String, at lineNumber : Int, options: FileCheckOptions) {
    func mino(_ l : String.Index?, _ r : String.Index?) -> String.Index? {
      if l == nil && r == nil {
        return nil
      } else if l == nil && r != nil {
        return r
      } else if l != nil && r == nil {
        return l
      }
      return min(l!, r!)
    }

    self.type = ty
    self.lineNumber = lineNumber
    var patternStr = substring(in: pattern, with: NSRange(location: 0, length: pattern.count))
    self.patternLoc = CheckLoc.inBuffer(pattern.baseAddress!, buf)
    self.options = options

    // Check that there is something on the line.
    if patternStr.isEmpty {
      diagnose(.warning, at: self.patternLoc, with: "found empty check string with prefix '\(prefix):'", options: options)
      return nil
    }

    // Check to see if this is a fixed string, or if it has regex pieces.
    if !options.contains(.matchFullLines) &&
      (patternStr.utf8.count < 2 ||
        (patternStr.range(of: "{{") == nil
          &&
          patternStr.range(of: "[[") == nil))
    {
      self.fixedString = patternStr
      return
    } else {
      self.fixedString = ""
    }

    if options.contains(.matchFullLines) {
      regExPattern += "^"
      if !options.contains(.strictWhitespace) {
        regExPattern += " *"
      }
    }

    // Paren value #0 is for the fully matched string.  Any new
    // parenthesized values add from there.
    var curParen = 1

    // Otherwise, there is at least one regex piece.  Build up the regex pattern
    // by escaping scary characters in fixed strings, building up one big regex.
    while !patternStr.isEmpty {
      // RegEx matches.
      if patternStr.range(of: "{{")?.lowerBound == patternStr.startIndex {
        // This is the start of a regex match.  Scan for the }}.
        patternStr = patternStr.substring(from: patternStr.index(patternStr.startIndex, offsetBy: 2))
        guard let end = self.findRegexVarEnd(patternStr, brackets: (open: "{", close: "}"), terminator: "}}") else {
          let loc = CheckLoc.inBuffer(pattern.baseAddress!, buf)
          diagnose(.error, at: loc, with: "found start of regex string with no end '}}'", options: options)
          return nil
        }

        // Enclose {{}} patterns in parens just like [[]] even though we're not
        // capturing the result for any purpose.  This is required in case the
        // expression contains an alternation like: CHECK:  abc{{x|z}}def.  We
        // want this to turn into: "abc(x|z)def" not "abcx|zdef".
        regExPattern += "("
        curParen += 1

        let substr = patternStr.substring(to: end)
        let (res, paren) = self.addRegExToRegEx(substr, curParen)
        curParen = paren
        if res {
          return nil
        }
        regExPattern += ")"

        patternStr = patternStr.substring(from: patternStr.index(end, offsetBy: 2))
        continue
      }

      // Named RegEx matches.  These are of two forms: [[foo:.*]] which matches .*
      // (or some other regex) and assigns it to the FileCheck variable 'foo'. The
      // second form is [[foo]] which is a reference to foo.  The variable name
      // itself must be of the form "[a-zA-Z_][0-9a-zA-Z_]*", otherwise we reject
      // it.  This is to catch some common errors.
      if patternStr.hasPrefix("[[") {
        // Find the closing bracket pair ending the match.  End is going to be an
        // offset relative to the beginning of the match string.
        let regVar = patternStr.substring(from: patternStr.index(patternStr.startIndex, offsetBy: 2))
        guard let end = self.findRegexVarEnd(regVar, brackets: (open: "[", close: "]"), terminator: "]]") else {
          let loc = CheckLoc.inBuffer(pattern.baseAddress!, buf)
          diagnose(.error, at: loc, with: "invalid named regex reference, no ]] found", options: options)
          return nil
        }

        let matchStr = regVar.substring(to: end)
        patternStr = patternStr.substring(from: patternStr.index(end, offsetBy: 4))

        // Get the regex name (e.g. "foo").
        let nameEnd = matchStr.range(of: ":")
        let name : String
        if let end = nameEnd?.lowerBound {
          name = matchStr.substring(to: end)
        } else {
          name = matchStr
        }

        if name.isEmpty {
          let loc = CheckLoc.inBuffer(pattern.baseAddress!, buf)
          diagnose(.error, at: loc, with: "invalid name in named regex: empty name", options: options)
          return nil
        }

        // Verify that the name/expression is well formed. FileCheck currently
        // supports @LINE, @LINE+number, @LINE-number expressions. The check here
        // is relaxed, more strict check is performed in \c EvaluateExpression.
        var isExpression = false
        let diagLoc = CheckLoc.inBuffer(pattern.baseAddress!, buf)
        for (i, c) in name.characters.enumerated() {
          if i == 0 && c == "@" {
            if nameEnd == nil {
              diagnose(.error, at: diagLoc, with: "invalid name in named regex definition", options: options)
              return nil
            }
            isExpression = true
            continue
          }
          if c != "_" && isalnum(Int32(c.utf8CodePoint)) == 0 && (!isExpression || (c != "+" && c != "-")) {
            diagnose(.error, at: diagLoc, with: "invalid name in named regex", options: options)
            return nil
          }
        }

        // Name can't start with a digit.
        if isdigit(Int32(name.utf8.first!)) != 0 {
          diagnose(.error, at: diagLoc, with: "invalid name in named regex", options: options)
          return nil
        }

        // Handle [[foo]].
        guard let ne = nameEnd else {
          // Handle variables that were defined earlier on the same line by
          // emitting a backreference.
          if let varParenNum = self.variableDefs[name] {
            if varParenNum < 1 || varParenNum > 9 {
              diagnose(.error, at: diagLoc, with: "Can't back-reference more than 9 variables", options: options)
              return nil
            }
            self.addBackrefToRegEx(varParenNum)
          } else {
            variableUses.append((name, regExPattern.characters.count))
          }
          continue
        }

        // Handle [[foo:.*]].
        self.variableDefs[name] = curParen
        regExPattern += "("
        curParen += 1

        let (res, paren) = self.addRegExToRegEx(matchStr.substring(from: matchStr.index(after: ne.lowerBound)), curParen)
        curParen = paren
        if res {
          return nil
        }

        regExPattern += ")"
      }

      // Handle fixed string matches.
      // Find the end, which is the start of the next regex.
      if let fixedMatchEnd = mino(patternStr.range(of: "{{")?.lowerBound, patternStr.range(of: "[[")?.lowerBound) {
        self.regExPattern += NSRegularExpression.escapedPattern(for: patternStr.substring(to: fixedMatchEnd))
        patternStr = patternStr.substring(from: fixedMatchEnd)
      } else {
        // No more matches, time to quit.
        break
      }
    }

    if options.contains(.matchFullLines) {
      if !options.contains(.strictWhitespace) {
        regExPattern += " *"
        regExPattern += "$"
      }
    }
  }

  private func addBackrefToRegEx(_ backRef : Int) {
    assert(backRef >= 1 && backRef <= 9, "Invalid backref number")
    let Backref = "\\\(backRef)"
    self.regExPattern += Backref
  }

  /// - returns: Returns a value on success or nil on a syntax error.
  private func evaluateExpression(_ e : String) -> String? {
    var expr = e
    // The only supported expression is @LINE([\+-]\d+)?
    if !expr.hasPrefix("@LINE") {
      return nil
    }
    expr = expr.substring(from: expr.index(expr.startIndex, offsetBy: "@LINE".utf8.count))
    guard let firstC = expr.characters.first else {
      return "\(self.lineNumber)"
    }

    if firstC == "+" {
      expr = expr.substring(from: expr.index(after: expr.startIndex))
    } else if firstC != "-" {
      return nil
    }

    guard let offset = Int(expr, radix: 10) else {
      return nil
    }
    return "\(self.lineNumber + offset)"
  }

  /// Matches the pattern string against the input buffer.
  ///
  /// This returns the position that is matched or npos if there is no match. If
  /// there is a match, the range of the match is returned.
  ///
  /// The variable table provides the current values of filecheck variables and
  /// is updated if this match defines new values.
  func match(_ buffer : String, _ variableTable : BoxedTable) -> NSRange? {
    // If this is the EOF pattern, match it immediately.
    if self.type == .EOF {
      return NSRange(location: buffer.utf8.count, length: 0)
    }

    // If this is a fixed string pattern, just match it now.
    if !self.fixedString.isEmpty {
      if let b = buffer.range(of: self.fixedString)?.lowerBound {
        return NSRange(location: buffer.distance(from: buffer.startIndex, to: b), length: self.fixedString.utf8.count)
      }
      return nil
    }

    // Regex match.

    // If there are variable uses, we need to create a temporary string with the
    // actual value.
    var regExToMatch = self.regExPattern
    if !self.variableUses.isEmpty {
      var insertOffset = 0
      for (v, offset) in self.variableUses {
        var value : String = ""

        if let c = v.characters.first, c == "@" {
          guard let v = self.evaluateExpression(v) else {
            return nil
          }
          value = v
        } else {
          guard let val = variableTable[v] else {
            return nil
          }

          // Look up the value and escape it so that we can put it into the regex.
          value += NSRegularExpression.escapedPattern(for: val)
        }

        // Plop it into the regex at the adjusted offset.
        regExToMatch.insert(contentsOf: value.characters, at: regExToMatch.index(regExToMatch.startIndex, offsetBy: offset + insertOffset))
        insertOffset += value.utf8.count
      }
    }

    // Match the newly constructed regex.
    guard let r = try? NSRegularExpression(pattern: regExToMatch, options: []) else {
      return nil
    }
    let matchInfo = r.matches(in: buffer, options: [], range: NSRange(location: 0, length: buffer.utf8.count))

    // Successful regex match.
    guard let fullMatch = matchInfo.first else {
      return nil
    }

    // If this defines any variables, remember their values.
    for (v, index) in self.variableDefs {
      assert(index < fullMatch.numberOfRanges, "Internal paren error")
      #if os(macOS)
        let r = fullMatch.rangeAt(index)
      #else
        let r = fullMatch.range(at: index)
      #endif
      variableTable[v] = buffer.substring(
        with: Range<String.Index>(
          uncheckedBounds: (
            buffer.index(buffer.startIndex, offsetBy: r.location),
            buffer.index(buffer.startIndex, offsetBy: NSMaxRange(r))
          )
        )
      )
    }

    return fullMatch.range
  }

  /// Finds the closing sequence of a regex variable usage or definition.
  ///
  /// The given string has to start in the beginning of the definition
  /// (right after the opening sequence). Returns the offset of the closing
  /// sequence within the string, or nil if it was not found.
  private func findRegexVarEnd(_ regVar : String, brackets: (open: Character, close: Character), terminator: String) -> String.Index? {
    var string = regVar
    // Offset keeps track of the current offset within the input Str
    var offset = regVar.startIndex
    // [...] Nesting depth
    var bracketDepth = 0

    while let firstChar = string.characters.first {
      if string.hasPrefix(terminator) && bracketDepth == 0 {
        return offset
      }
      if firstChar == "\\" {
        // Backslash escapes the next char within regexes, so skip them both.
        string = string.substring(from: string.index(string.startIndex, offsetBy: 2))
        offset = regVar.index(offset, offsetBy: 2)
      } else {
        switch firstChar {
        case brackets.open:
          bracketDepth += 1
        case brackets.close:
          if bracketDepth == 0 {
            diagnose(.error,
                     at: .string(regVar),
                     with: "missing closing \"\(brackets.close)\" for regex variable",
              options: self.options
            )
            return nil
          }
          bracketDepth -= 1
        default:
          break
        }
        string = string.substring(from: string.index(after: string.startIndex))
        offset = regVar.index(after: offset)
      }
    }

    return nil
  }

  private func addRegExToRegEx(_ RS : String, _ cur : Int) -> (Bool, Int) {
    do {
      let r = try NSRegularExpression(pattern: RS, options: [])
      self.regExPattern += RS
      return (false, cur + r.numberOfCaptureGroups)
    } catch let e {
      diagnose(.error, at: self.patternLoc, with: "invalid regex: \(e)", options: self.options)
      return (true, cur)
    }
  }
}

/// Count the number of newlines in the specified range.
func countNumNewlinesBetween(_ r : String) -> (Int, String.Index?) {
  var range = r
  var NumNewLines = 0
  var firstNewLine : String.Index? = nil
  while true {
    // Scan for newline.
    guard let EOL = range.range(of: "\n")?.lowerBound ?? range.range(of: "\r")?.lowerBound else {
      return (NumNewLines, firstNewLine)
    }
    range = range.substring(from: EOL)
    if range.isEmpty {
      return (NumNewLines, firstNewLine)
    }

    NumNewLines += 1

    // Handle \n\r and \r\n as a single newline.
    //		if Range.utf8.count > 1 && (Range.utf8[1] == '\n' || Range[1] == '\r') && (Range[0] != Range[1]) {
    //			Range = Range.substr(1)
    //		}
    range = range.substring(from: range.index(after: range.startIndex))
    
    if NumNewLines == 1 {
      firstNewLine = range.startIndex
    }
  }
}
