import Foundation

public enum Try<T> {
  case Success(T)
  case Failure(String)

  public static func success(value: T) -> Try<T> {
    return .Success(value)
  }

  public static func failure(desc: String) -> Try<T> {
    return .Failure(desc)
  }

  public func flatMap<U>(@noescape f: T -> Try<U>) -> Try<U> {
    switch self {
    case Success(let value):
      return f(value)
    case Failure(let desc):
      return .failure(desc)
    }
  }

  public func map<U>(@noescape f: T -> U) -> Try<U> {
    return flatMap { e in .success(f(e)) }
  }

  public var value: T? {
    switch self {
    case Success(let value):
      return value
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

extension Try: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    switch self {
    case .Success(let value):
      return "Success(\(value))"
    case .Failure(let desc):
      return "Failure(\"\(desc)\")"
    }
  }

  public var debugDescription: String {
    switch self {
    case .Success(let value):
      return "Success(\(String(reflecting: value)))"
    case .Failure(let desc):
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
  case (.Success(let lhs), .Success(let rhs)):
    return lhs == rhs
  case (.Failure(let lhs), .Failure(let rhs)):
    return lhs == rhs
  default:
    return false
  }
}

public func !=<T: Equatable>(lhs: Try<T>, rhs: Try<T>) -> Bool {
  return !(lhs == rhs)
}
