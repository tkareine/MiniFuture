enum AppError: Error, CustomStringConvertible {
  case deliberate(String)
  case unsupported

  var description: String {
    switch self {
    case .deliberate(let s):
      return "AppError.deliberate(\"\(s)\")"
    case .unsupported:
      return "AppError.unsupported"
    }
  }
}
