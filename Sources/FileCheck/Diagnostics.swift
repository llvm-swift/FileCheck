import Foundation

func diagnose(_ kind : DiagnosticKind, at loc : CheckLocation, with message : String, options: FileCheckOptions) {
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

enum CheckLocation {
  case inBuffer(UnsafePointer<CChar>, UnsafeBufferPointer<CChar>)
  case string(String)
}
