func assertToString<T>(actual: T, expected: String) {
  assert(toString(actual) == expected)
}

func immediateFuturesExample() {
  let succeeded = Future.succeeded(1)

  assert(succeeded.isCompleted)
  assertToString(succeeded.get(), "Success(1)")

  let failed = Future<Int>.failed("2")

  assert(failed.isCompleted)
  assertToString(failed.get(), "Failure(2)")
}

func simpleAsyncFuturesExample() {
  assertToString(Future.async { Success([1]) }.get(), "Success([1])")
  assertToString(Future.async { Failure<[Int]>(toString([2])) }.get(), "Failure([2])")
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
simpleAsyncFuturesExample()
outerChainingFuturesExample()
innerChainingFuturesExample()
innerAndOuterChainingAsyncFuturesExample()

println("ok!")
