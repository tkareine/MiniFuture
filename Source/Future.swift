import Dispatch

struct FutureExecution {
  private static let sharedQueue = DispatchQueue.global()

  typealias Group = DispatchGroup

  static func makeGroup() -> Group {
    return DispatchGroup()
  }

  static func async(_ block: @escaping () -> Void) {
    sharedQueue.async(execute: block)
  }

  static func async(_ group: Group, block: @escaping () -> Void) {
    sharedQueue.async(group: group, execute: block)
  }

  static func sync(_ block: () -> Void) {
    sharedQueue.sync(execute: block)
  }

  static func notify(_ group: Group, block: @escaping () -> Void) {
    group.notify(queue: sharedQueue, execute: block)
  }

  static func wait(_ group: Group) {
    group.wait()
  }
}

public class Future<T> {
  /**
   - note: Eventually, `block` closure parameter gets called from a concurrent
   queue. Use proper synchronization when accessing shared state via references
   captured in the closure.
   */
  public static func async(_ block: @escaping () throws -> Try<T>) -> AsyncFuture<T> {
    return AsyncFuture(block)
  }

  public static func succeeded(_ val: T) -> ImmediateFuture<T> {
    return fromTry(.success(val))
  }

  public static func failed(_ error: Error) -> ImmediateFuture<T> {
    return fromTry(.failure(error))
  }

  public static func fromTry(_ val: Try<T>) -> ImmediateFuture<T> {
    return ImmediateFuture(val)
  }

  public static func promise() -> PromiseFuture<T> {
    return PromiseFuture()
  }

  public typealias CompletionCallback = (Try<T>) -> Void

  fileprivate var result: Try<T>?

  public var isCompleted: Bool {
    fatalError("must be overridden")
  }

  fileprivate var futureName: String {
    fatalError("must be overridden")
  }

  fileprivate init(_ val: Try<T>?) {
    result = val
  }

  public func get() -> Try<T> {
    fatalError("must be overridden")
  }

  /**
   - note: Eventually, `block` closure parameter gets called from a concurrent
   queue. Use proper synchronization when accessing shared state via references
   captured in the closure.
   */
  public func onComplete(_ block: @escaping CompletionCallback) {
    fatalError("must be overridden")
  }

  /**
   - note: Eventually, `f` closure parameter gets called from a concurrent
   queue. Use proper synchronization when accessing shared state via references
   captured in the closure.
   */
  public func flatMap<U>(_ f: @escaping (T) throws -> Future<U>) -> Future<U> {
    let promise = PromiseFuture<U>()
    onComplete { res in
      switch res {
      case .success(let value):
        let fut: Future<U>
        do {
          fut = try f(value)
        } catch {
          fut = Future<U>.failed(error)
        }
        fut.onComplete(promise.complete)
      case .failure(let error):
        // we cannot cast dynamically with generic types, so let's create a
        // new value
        promise.complete(.failure(error))
      }
    }
    return promise
  }

  /**
   - note: Eventually, `f` closure parameter gets called from a concurrent
   queue. Use proper synchronization when accessing shared state via references
   captured in the closure.
   */
  public func map<U>(_ f: @escaping (T) throws -> U) -> Future<U> {
    return flatMap { e in
      do {
        return Future<U>.succeeded(try f(e))
      } catch {
        return Future<U>.failed(error)
      }
    }
  }
}

public class ImmediateFuture<T>: Future<T> {
  override public var isCompleted: Bool {
    return result != nil
  }

  override fileprivate var futureName: String {
    return "ImmediateFuture"
  }

  fileprivate init(_ val: Try<T>) {
    super.init(val)
  }

  override public func get() -> Try<T> {
    return result!
  }

  override public func onComplete(_ block: @escaping CompletionCallback) {
    let res = result!
    FutureExecution.async { block(res) }
  }
}

public class AsyncFuture<T>: Future<T> {
  private let Group = FutureExecution.makeGroup()

  override public var isCompleted: Bool {
    var res = false
    FutureExecution.sync { [unowned self] in
      res = self.result != nil
    }
    return res
  }

  override fileprivate var futureName: String {
    return "AsyncFuture"
  }

  fileprivate init(_ block: @escaping () throws -> Try<T>) {
    super.init(nil)
    FutureExecution.async(Group) {
      let res: Try<T>
      do {
        res = try block()
      } catch {
        res = Try<T>.failure(error)
      }
      self.result = res
    }
  }

  override public func get() -> Try<T> {
    FutureExecution.wait(Group)
    return result!
  }

  override public func onComplete(_ block: @escaping CompletionCallback) {
    FutureExecution.notify(Group) {
      block(self.result!)
    }
  }
}

public class PromiseFuture<T>: Future<T> {
  private let condition = Condition()
  private var completionCallbacks: [CompletionCallback] = []

  override public var isCompleted: Bool {
    return condition.synchronized { _ in
      result != nil
    }
  }

  override fileprivate var futureName: String {
    return "PromiseFuture"
  }

  fileprivate init() {
    super.init(nil)
  }

  public func resolve(_ value: T) {
    complete(.success(value))
  }

  public func reject(_ error: Error) {
    complete(.failure(error))
  }

  public func complete(_ value: Try<T>) {
    let callbacks: [CompletionCallback] = condition.synchronized { _ in
      if result != nil {
        fatalError("Tried to complete PromiseFuture with \(value.value), but " +
          "the future is already completed with \(result!)")
      }

      result = value

      let callbacks = completionCallbacks
      completionCallbacks = []

      condition.signal()

      return callbacks
    }

    for block in callbacks {
      FutureExecution.async { block(value) }
    }
  }

  public func completeWith(_ future: Future<T>) {
    future.onComplete { self.complete($0) }
  }

  override public func get() -> Try<T> {
    return condition.synchronized { wait in
      while result == nil {
        wait()
      }

      return result!
    }
  }

  override public func onComplete(_ block: @escaping CompletionCallback) {
    let res: Try<T>? = condition.synchronized { _ in
      let res = result

      if res == nil {
        completionCallbacks.append(block)
      }

      return res
    }

    if let r = res {
      FutureExecution.async { block(r) }
    }
  }
}

extension Future: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    return "\(futureName)(\(result))"
  }

  public var debugDescription: String {
    return "\(futureName)(\(String(reflecting: result)))"
  }
}
