import Dispatch

struct FutureExecution {
  private static let sharedQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

  typealias Group = dispatch_group_t

  static func makeGroup() -> Group {
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
  public class func async(block: () -> Try<T>) -> Future<T> {
    return AsyncFuture(block)
  }

  public class func succeeded(val: T) -> Future<T> {
    return fromTry(.Success(val))
  }

  public class func failed(val: String) -> Future<T> {
    return fromTry(.Failure(val))
  }

  public class func fromTry(val: Try<T>) -> Future<T> {
    return ImmediateFuture(val)
  }

  public class func promise() -> PromiseFuture<T> {
    return PromiseFuture()
  }

  public typealias CompletionCallback = Try<T> -> Void

  private var result: Try<T>?

  public var isCompleted: Bool {
    return result != nil
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

  public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
    let promise = PromiseFuture<U>()
    onComplete { res in
      switch res {
      case .Success(let val):
        f(val()).onComplete(promise.complete)
      case .Failure(let desc):
        // we cannot cast dynamically with generic types, so let's create a
        // new value
        promise.complete(.Failure(desc))
      }
    }
    return promise
  }

  public func map<U>(f: T -> U) -> Future<U> {
    return flatMap { e in Future<U>.succeeded(f(e)) }
  }
}

public class ImmediateFuture<T>: Future<T> {
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
    FutureExecution.dispatchAsync { block(res) }
  }
}

public class AsyncFuture<T>: Future<T> {
  private let Group = FutureExecution.makeGroup()

  override private var futureName: String {
    return "AsyncFuture"
  }

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

  override private var futureName: String {
    return "PromiseFuture"
  }

  private init() {
    super.init(nil)
  }

  public func resolve(value: T) {
    complete(.Success(value))
  }

  public func reject(description: String) {
    complete(.Failure(description))
  }

  public func complete(value: Try<T>) {
    let callbacks: [CompletionCallback] = condition.synchronized { _ in
      if self.result != nil {
        fatalError("Tried to complete PromiseFuture with \(value.value), but " +
          "the future is already completed with \(self.result!.value)")
      }

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

extension Future: Printable, DebugPrintable {
  public var description: String {
    return describeWith(print)
  }

  public var debugDescription: String {
    return describeWith(debugPrint)
  }

  private func describeWith(printFn: (Any, inout String) -> Void) -> String {
    var str = "\(futureName)("
    printFn(result, &str)
    print(")", &str)
    return str
  }
}
