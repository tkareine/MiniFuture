import Dispatch

struct FutureExecution {
  private static var sharedQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

  typealias Group = dispatch_group_t

  static func newGroup() -> Group {
    return dispatch_group_create()
  }

  static func dispatchAsync(block: () -> Void) {
    dispatch_async(sharedQueue, block)
  }

  static func dispatchAsync(group: Group, block: () -> Void) {
    dispatch_group_async(group, sharedQueue, block)
  }

  static func dispatchNotify(group: Group, block: () -> Void) {
    dispatch_group_notify(group, sharedQueue, block)
  }

  static func wait(group: Group) -> Void {
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
  }
}

public class Future<T> {
  class func async(block: () -> Try<T>) -> Future<T> {
    return AsyncFuture(block)
  }

  class func succeeded(val: T) -> Future<T> {
    return fromTry(Success(val))
  }

  class func failed(val: String) -> Future<T> {
    return fromTry(Failure(val))
  }

  class func fromTry(val: Try<T>) -> Future<T> {
    return ImmediateFuture(val)
  }

  public typealias CompletionCallback = Try<T> -> Void

  private var result: Try<T>?

  public var isCompleted: Bool {
    return result != nil
  }

  private init(_ val: Try<T>?) {
    result = val
  }

  public func get() -> Try<T> {
    assertionFailure("must be overridden")
  }

  public func onComplete(block: CompletionCallback) {
    assertionFailure("must be overridden")
  }

  public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
    let promise = PromiseFuture<U>()
    onComplete { res in
      switch res {
      case let success as Success<T>:
        f(success.val).onComplete(promise.complete)
      case let failure as Failure<T>:
        // we cannot cast dynamically with generic types, so let's create new value
        promise.complete(Failure(failure.desc))
      default:
        assertionFailure("unknown Try type")
      }
    }
    return promise
  }

  public func map<U>(f: T -> U) -> Future<U> {
    return flatMap { e in Future<U>.succeeded(f(e)) }
  }
}

public class ImmediateFuture<T>: Future<T> {
  private init(_ val: Try<T>) {
    super.init(val)
  }

  override public func get() -> Try<T> {
    return result!
  }

  override public func onComplete(block: CompletionCallback) {
    let res = result!
    FutureExecution.dispatchAsync { block(res) }
  }
}

public class AsyncFuture<T>: Future<T> {
  private let Group = FutureExecution.newGroup()

  private init(_ block: () -> Try<T>) {
    super.init(nil)
    FutureExecution.dispatchAsync(Group) {
      self.result = block()
    }
  }

  override public func get() -> Try<T> {
    FutureExecution.wait(Group)
    return result!
  }

  override public func onComplete(block: CompletionCallback) {
    FutureExecution.dispatchNotify(Group) {
      block(self.result!)
    }
  }
}

public class PromiseFuture<T>: Future<T> {
  private let condition = Condition()
  private var completionCallbacks: [CompletionCallback] = []

  private init() {
    super.init(nil)
  }

  private func complete(value: Try<T>) {
    let callbacks: [CompletionCallback] = condition.synchronized { _ in
      assert(self.result == nil, "must complete only once")

      self.result = value

      let callbacks = self.completionCallbacks
      self.completionCallbacks = []

      self.condition.signal()

      return callbacks
    }

    for block in callbacks {
      FutureExecution.dispatchAsync { block(value) }
    }
  }

  override public func get() -> Try<T> {
    return condition.synchronized { wait in
      while self.result == nil {
        wait()
      }

      return self.result!
    }
  }

  override public func onComplete(block: CompletionCallback) {
    let res: Try<T>? = condition.synchronized { _ in
      let res = self.result

      if res == nil {
        self.completionCallbacks.append(block)
      }

      return res
    }

    if let r = res {
      FutureExecution.dispatchAsync { block(r) }
    }
  }
}
