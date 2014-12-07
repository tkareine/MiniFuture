import Foundation

public class Try<T>: Printable {
  public let value: T?

  private init() {}

  private init(_ val: T) {
    value = val
  }

  public var description: String {
    assertionFailure("must be implemented in a subclass")
  }

  public var isSuccess: Bool {
    assertionFailure("must be implemented in a subclass")
  }

  public var isFailure: Bool {
    return !isSuccess
  }

  public func flatMap<U>(f: T -> Try<U>) -> Try<U> {
    switch self {
    case let s as Success<T>:
      return f(s.val)
    case let f as Failure<T>:
      return Failure(f.desc)
    default:
      assertionFailure("unknown Try type")
    }
  }

  public func map<U>(f: T -> U) -> Try<U> {
    return flatMap { e in Success(f(e)) }
  }
}

public class Success<T>: Try<T> {
  public var val: T {
    return value!
  }

  public override init(_ val: T) {
    super.init(val)
  }

  override public var description: String {
    return "Success(\(val))"
  }

  override public var isSuccess: Bool {
    return true
  }
}

public class Failure<T>: Try<T> {
  public let desc: String

  public init(_ d: String) {
    desc = d
    super.init()
  }

  override public var description: String {
    return "Failure(\(desc))"
  }

  override public var isSuccess: Bool {
    return false
  }
}
