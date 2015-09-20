enum Error: ErrorType, CustomStringConvertible {
  case Deliberate(String)
  case Unsupported

  var description: String {
    switch self {
    case .Deliberate(let s):
      return "Deliberate(\"\(s)\")"
    case .Unsupported:
      return "Unsupported"
    }
  }
}
