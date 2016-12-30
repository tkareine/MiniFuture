import Foundation

public enum Try<T> {
  case success(T)
  case failure(Error)

  public func flatMap<U>(_ f: (T) throws -> Try<U>) -> Try<U> {
    switch self {
    case .success(let value):
      do {
        return try f(value)
      } catch {
        return .failure(error)
      }
    case .failure(let error):
      return .failure(error)
    }
  }

  public func map<U>(_ f: (T) throws -> U) -> Try<U> {
    return flatMap { e in
      do {
        return .success(try f(e))
      } catch {
        return .failure(error)
      }
    }
  }

  public func value() throws -> T {
    switch self {
    case .success(let value):
      return value
    case .failure(let error):
      throw error
    }
  }

  public var isSuccess: Bool {
    switch self {
    case .success:
      return true
    case .failure:
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
    case .success(let value):
      return "Try.success(\(value))"
    case .failure(let error):
      return "Try.failure(\(error))"
    }
  }

  public var debugDescription: String {
    switch self {
    case .success(let value):
      return "Try.success(\(String(reflecting: value)))"
    case .failure(let error):
      return "Try.failure(\(String(reflecting: error)))"
    }
  }
}

/**
 * Try enumeration does not adopt Equatable protocol, because that would limit
 * the allowed values of generic type T. Instead, we provide `==` operator.
 */
public func ==<T: Equatable>(lhs: Try<T>, rhs: Try<T>) -> Bool {
  switch (lhs, rhs) {
  case (.success(let lhs), .success(let rhs)):
    return lhs == rhs
  case (.failure(let lhs as NSError), .failure(let rhs as NSError)):
    return lhs.domain == rhs.domain
        && lhs.code == rhs.code
  default:
    return false
  }
}

public func !=<T: Equatable>(lhs: Try<T>, rhs: Try<T>) -> Bool {
  return !(lhs == rhs)
}
