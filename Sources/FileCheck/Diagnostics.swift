import Foundation
import Chalk

func diagnose(_ kind : DiagnosticKind, at loc : CheckLocation, with message : String, options: FileCheckOptions) {
  let disableColors = options.contains(.disableColors) || isatty(fileno(stdout)) != 1
  if disableColors {
    print("\(kind): \(message)")
  } else {
      print("\(kind, color: kind.color, style: .bold): \(message, style: .bold)")
  }

  let msg = loc.message
  if !msg.isEmpty {
    print(msg)
  }
}

enum DiagnosticKind: String {
  case error
  case warning
  case note

  var color: Color {
    switch self {
    case .error: return .red
    case .warning: return .magenta
    case .note: return .green
    }
  }
}

enum CheckLocation {
  case inBuffer(UnsafePointer<CChar>, UnsafeBufferPointer<CChar>)
  case string(String)
}
