import Foundation

public enum Try<T> {
  case Success(T)
  case Failure(ErrorType)

  public static func success(value: T) -> Try<T> {
    return .Success(value)
  }

  public static func failure(error: ErrorType) -> Try<T> {
    return .Failure(error)
  }

  public func flatMap<U>(@noescape f: T -> Try<U>) -> Try<U> {
    switch self {
    case Success(let value):
      return f(value)
    case Failure(let error):
      return .Failure(error)
    }
  }

  public func map<U>(@noescape f: T -> U) -> Try<U> {
    return flatMap { e in .Success(f(e)) }
  }

  public func value() throws -> T {
    switch self {
    case Success(let value):
      return value
    case Failure(let error):
      throw error
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
    case .Failure(let error):
      return "Failure(\(error))"
    }
  }

  public var debugDescription: String {
    switch self {
    case .Success(let value):
      return "Success(\(String(reflecting: value)))"
    case .Failure(let error):
      return "Failure(\(String(reflecting: error)))"
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
  case (.Failure(let lhs as NSError), .Failure(let rhs as NSError)):
    return lhs.domain == rhs.domain
        && lhs.code == rhs.code
  default:
    return false
  }
}

public func !=<T: Equatable>(lhs: Try<T>, rhs: Try<T>) -> Bool {
  return !(lhs == rhs)
}
