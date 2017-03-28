import Foundation

func diagnose(_ kind : DiagnosticKind, at loc : CheckLoc, with message : String, options: FileCheckOptions) {
  let disableColors = options.contains(.disableColors)
  if disableColors {
    print("\(kind): \(message)")
  } else {
    diagnosticStream.write("\(kind): ", with: [.bold, kind.color])
    diagnosticStream.write("\(message)\n", with: [.bold])
  }

  let msg = loc.message
  if !msg.isEmpty {
    if disableColors {
      print(msg)
    } else {
      diagnosticStream.write("\(msg)\n")
    }
  }
}

enum DiagnosticKind: String {
  case error
  case warning
  case note

  var color: ANSIColor {
    switch self {
    case .error: return .red
    case .warning: return .magenta
    case .note: return .green
    }
  }
}

struct StdOutStream: TextOutputStream {
  mutating func write(_ string: String) {
    print(string, terminator: "")
  }
}

var stdoutStream = StdOutStream()
var diagnosticStream = ColoredANSIStream(&stdoutStream)

enum CheckLoc {
  case inBuffer(UnsafePointer<CChar>, UnsafeBufferPointer<CChar>)
  case string(String)

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
