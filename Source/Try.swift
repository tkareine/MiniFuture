import Foundation

public enum Try<T> {
  /// TODO: Replace `@autoclosure () -> T` in Success with just `T` when
  /// Swift supports generic associated values.
  case Success(@autoclosure () -> T)
  case Failure(String)

  public func flatMap<U>(f: T -> Try<U>) -> Try<U> {
    switch self {
    case Success(let val):
      return f(val())
    case Failure(let desc):
      return .Failure(desc)
    }
  }

  public func map<U>(f: T -> U) -> Try<U> {
    return flatMap { e in .Success(f(e)) }
  }

  public var value: T? {
    switch self {
    case Success(let val):
      return val()
    case Failure:
      return nil
    }
  }

  public var failureDescription: String? {
    switch self {
    case Success:
      return nil
    case Failure(let desc):
      return desc
    }
  }

  public var isSuccess: Bool {
    switch self {
    case Success:
      return true
    case Failure:
      return false
    }
  }

  public var isFailure: Bool {
    return !isSuccess
  }
}

extension Try: Printable, DebugPrintable {
  public var description: String {
    return describeWith(print)
  }

  public var debugDescription: String {
    return describeWith(debugPrint)
  }

  private func describeWith(printFn: (Any, inout String) -> Void) -> String {
    switch self {
    case Success(let val):
      var str = ""
      print("Success(", &str)
      printFn(val(), &str)
      print(")", &str)
      return str
    case Failure(let desc):
      return "Failure(\"\(desc)\")"
    }
  }
}

/**
 * Try enumeration does not adopt Equatable protocol, because that would limit
 * the allowed values of generic type T. Instead, we provide `==` operator.
 */
public func ==<T: Equatable>(lhs: Try<T>, rhs: Try<T>) -> Bool {
  switch (lhs, rhs) {
  case (.Success(let lhsVal), .Success(let rhsVal)):
    return lhsVal() == rhsVal()
  case (.Failure(let lhsDesc), .Failure(let rhsDesc)):
    return lhsDesc == rhsDesc
  default:
    return false
  }
}

public func !=<T: Equatable>(lhs: Try<T>, rhs: Try<T>) -> Bool {
  return !(lhs == rhs)
}
