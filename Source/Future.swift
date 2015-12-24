import Dispatch

struct FutureExecution {
  private static let sharedQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

  typealias Group = dispatch_group_t

  static func makeGroup() -> Group {
    return dispatch_group_create()
  }

  static func async(block: () -> Void) {
    dispatch_async(sharedQueue, block)
  }

  static func async(group: Group, block: () -> Void) {
    dispatch_group_async(group, sharedQueue, block)
  }

  static func sync(block: () -> Void) {
    dispatch_sync(sharedQueue, block)
  }

  static func notify(group: Group, block: () -> Void) {
    dispatch_group_notify(group, sharedQueue, block)
  }

  static func wait(group: Group) {
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
  }
}

public class Future<T> {
  public class func async(block: () throws -> Try<T>) -> AsyncFuture<T> {
    return AsyncFuture(block)
  }

  public class func succeeded(val: T) -> ImmediateFuture<T> {
    return fromTry(.Success(val))
  }

  public class func failed(error: ErrorType) -> ImmediateFuture<T> {
    return fromTry(.Failure(error))
  }

  public class func fromTry(val: Try<T>) -> ImmediateFuture<T> {
    return ImmediateFuture(val)
  }

  public class func promise() -> PromiseFuture<T> {
    return PromiseFuture()
  }

  public typealias CompletionCallback = Try<T> -> Void

  private var result: Try<T>?

  public var isCompleted: Bool {
    fatalError("must be overridden")
  }

  private var futureName: String {
    fatalError("must be overridden")
  }

  private init(_ val: Try<T>?) {
    result = val
  }

  public func get() -> Try<T> {
    fatalError("must be overridden")
  }

  public func onComplete(block: CompletionCallback) {
    fatalError("must be overridden")
  }

  public func flatMap<U>(f: T throws -> Future<U>) -> Future<U> {
    let promise = PromiseFuture<U>()
    onComplete { res in
      switch res {
      case .Success(let value):
        let fut: Future<U>
        do {
          fut = try f(value)
        } catch {
          fut = Future<U>.failed(error)
        }
        fut.onComplete(promise.complete)
      case .Failure(let error):
        // we cannot cast dynamically with generic types, so let's create a
        // new value
        promise.complete(.Failure(error))
      }
    }
    return promise
  }

  public func map<U>(f: T throws -> U) -> Future<U> {
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

  override private var futureName: String {
    return "ImmediateFuture"
  }

  private init(_ val: Try<T>) {
    super.init(val)
  }

  override public func get() -> Try<T> {
    return result!
  }

  override public func onComplete(block: CompletionCallback) {
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

  override private var futureName: String {
    return "AsyncFuture"
  }

  private init(_ block: () throws -> Try<T>) {
    super.init(nil)
    FutureExecution.async(Group) {
      let res: Try<T>
      do {
        res = try block()
      } catch {
        res = Try<T>.Failure(error)
      }
      self.result = res
    }
  }

  override public func get() -> Try<T> {
    FutureExecution.wait(Group)
    return result!
  }

  override public func onComplete(block: CompletionCallback) {
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

  override private var futureName: String {
    return "PromiseFuture"
  }

  private init() {
    super.init(nil)
  }

  public func resolve(value: T) {
    complete(.Success(value))
  }

  public func reject(error: ErrorType) {
    complete(.Failure(error))
  }

  public func complete(value: Try<T>) {
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

  override public func get() -> Try<T> {
    return condition.synchronized { wait in
      while result == nil {
        wait()
      }

      return result!
    }
  }

  override public func onComplete(block: CompletionCallback) {
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
