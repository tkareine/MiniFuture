import Foundation

let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

func assertToString<T>(actual: T, expected: String) {
  assert(toString(actual) == expected)
}

func immediateFuturesExample() {
  let succeeded = Future.succeeded(1)

  assert(succeeded.isCompleted)
  assertToString(succeeded.get(), "Success(1)")

  let failed = Future<Int>.failed("deliberate")

  assert(failed.isCompleted)
  assertToString(failed.get(), "Failure(deliberate)")
}

func asyncFuturesExample() {
  let succeeding = Future<Int>.async {
    NSThread.sleepForTimeInterval(0.2)
    return Success(1)
  }
  assertToString(succeeding.get(), "Success(1)")

  let failing = Future<Int>.async {
    NSThread.sleepForTimeInterval(0.2)
    return Failure("deliberate")
  }
  assertToString(failing.get(), "Failure(deliberate)")
}

func promiseFuturesExample() {
  let fut = Future<Int>.promise()

  dispatch_async(queue) {
    NSThread.sleepForTimeInterval(0.2)
    fut.resolve(1)
  }

  assert(fut.isCompleted == false)

  let result = fut.get()
  assert(fut.isCompleted == true)
  assertToString(result, "Success(1)")
}

func outerChainingFuturesExample() {
  let fut0: Future<Int> = Future.async { Success(0) }
  let fut1: Future<[Int]> = fut0.flatMap { Future.succeeded([$0, 1]) }
  let fut2: Future<[Int]> = fut1.flatMap { e in Future.failed(toString(e + [2])) }
  let fut3: Future<[Int]> = fut2.flatMap { Future.succeeded($0 + [3]) }

  assertToString(fut0.get(), "Success(0)")
  assertToString(fut1.get(), "Success([0, 1])")
  assertToString(fut2.get(), "Failure([0, 1, 2])")
  assertToString(fut3.get(), "Failure([0, 1, 2])")
}

func innerChainingFuturesExample() {
  let fut: Future<[Int]> = Future.succeeded([0]).flatMap { e in
    Future.succeeded(e + [1]).flatMap { e in
      let f: Future<[Int]> = Future.async { Failure(toString(e + [2])) }
      return f.flatMap { Future.succeeded($0 + [3]) }
    }
  }

  assertToString(fut.get(), "Failure([0, 1, 2])")
}

func innerAndOuterChainingAsyncFuturesExample() {
  let futBegin = Future.async { Success(0) }
  let futEnd: Future<[Int]> = futBegin.flatMap { e0 in
    let futIn0 = Future.succeeded(10).flatMap { e1 in
      Future.async { Success([e1] + [11]) }
    }

    let futIn1 = Future.succeeded([20]).flatMap {
      Future.succeeded($0 + [21])
    }

    return futIn0.flatMap { e1 in
      return futIn1.flatMap { e2 in
        Future.succeeded([e0] + e1 + e2)
      }
    }
  }

  assertToString(futBegin.get(), "Success(0)")
  assertToString(futEnd.get(), "Success([0, 10, 11, 20, 21])")
}

immediateFuturesExample()
asyncFuturesExample()
promiseFuturesExample()
outerChainingFuturesExample()
innerChainingFuturesExample()
innerAndOuterChainingAsyncFuturesExample()

println("ok!")
