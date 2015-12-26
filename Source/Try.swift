import Foundation

public enum Try<T> {
  case Success(T)
  case Failure(ErrorType)

  public func flatMap<U>(@noescape f: T throws -> Try<U>) -> Try<U> {
    switch self {
    case Success(let value):
      do {
        return try f(value)
      } catch {
        return .Failure(error)
      }
    case Failure(let error):
      return .Failure(error)
    }
  }

  public func map<U>(@noescape f: T throws -> U) -> Try<U> {
    return flatMap { e in
      do {
        return .Success(try f(e))
      } catch {
        return .Failure(error)
      }
    }
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
