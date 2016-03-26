import XCTest

class FutureTests: XCTestCase {
  func testGetSucceedingImmediateFuture() {
    let fut = Future.succeeded(1)

    XCTAssertTrue(fut.isCompleted)  // no need to wait with `get`

    let res = fut.get()

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
    XCTAssertEqual(fut.description, "ImmediateFuture(Optional(Success(1)))")
    XCTAssertEqual(fut.debugDescription, "ImmediateFuture(Optional(Success(1)))")
    XCTAssert(res == fut.get())
  }

  func testGetFailingImmediateFuture() {
    let fut = Future<Int>.failed(Error.Deliberate("42"))

    XCTAssertTrue(fut.isCompleted)  // no need to wait with `get`

    fut.get()

    XCTAssertEqual(fut.get().description, "Failure(Deliberate(\"42\"))")
    XCTAssertEqual(fut.description, "ImmediateFuture(Optional(Failure(Deliberate(\"42\"))))")
    XCTAssertEqual(fut.debugDescription, "ImmediateFuture(Optional(Failure(Deliberate(\"42\"))))")
  }

  func testGetSucceedingAsyncFuture() {
    let sem = Semaphore()
    let fut = Future<Int>.async {
      sem.wait()
      return .Success(1)
    }

    XCTAssertFalse(fut.isCompleted)
    XCTAssertEqual(fut.description, "AsyncFuture(nil)")

    sem.signal()
    let res = fut.get()

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
    XCTAssertEqual(fut.description, "AsyncFuture(Optional(Success(1)))")
    XCTAssert(res == fut.get())
  }

  func testGetFailingAsyncFuture() {
    let fut = Future<Int>.async { .Failure(Error.Deliberate("42")) }
    let res = fut.get()

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(res.description, "Failure(Deliberate(\"42\"))")
    XCTAssertEqual(fut.description, "AsyncFuture(Optional(Failure(Deliberate(\"42\"))))")
  }

  func testGetThrowingAsyncFuture() {
    let fut = Future<Int>.async { throw Error.Deliberate("42") }
    let res = fut.get()

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(res.description, "Failure(Deliberate(\"42\"))")
    XCTAssertEqual(fut.description, "AsyncFuture(Optional(Failure(Deliberate(\"42\"))))")
  }

  func testGetSucceedingPromiseFuture() {
    let sem = Semaphore()
    let fut = Future<Int>.promise()

    FutureExecution.async {
      sem.wait()
      fut.resolve(1)
    }

    XCTAssertFalse(fut.isCompleted)
    XCTAssertEqual(fut.description, "PromiseFuture(nil)")

    sem.signal()
    let res = fut.get()

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
    XCTAssertEqual(fut.description, "PromiseFuture(Optional(Success(1)))")
    XCTAssert(res == fut.get())
  }

  func testGetFailingPromiseFuture() {
    let fut = Future<Int>.promise()

    XCTAssertFalse(fut.isCompleted)

    fut.reject(Error.Deliberate("42"))

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(fut.get().description, "Failure(Deliberate(\"42\"))")
    XCTAssertEqual(fut.description, "PromiseFuture(Optional(Failure(Deliberate(\"42\"))))")
  }

  func testOnCompleteImmediateFuture() {
    let sem = Semaphore()
    let fut = Future.succeeded(1)
    var res: Try<Int>!

    fut.onComplete { r in
      res = r
      sem.signal()
    }

    sem.wait()

    XCTAssertTrue(fut.isCompleted)
    XCTAssert(res == fut.get())
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testOnCompleteAsyncFuture() {
    let sem = Semaphore()
    let fut = Future.async { .Success(1) }
    var res: Try<Int>!

    fut.onComplete { r in
      res = r
      sem.signal()
    }

    sem.wait()

    XCTAssertTrue(fut.isCompleted)
    XCTAssert(res == fut.get())
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testOnCompletePromiseFuture() {
    let sem = Semaphore()
    let fut = Future<Int>.promise()
    var res: Try<Int>!

    fut.onComplete { r in
      res = r
      sem.signal()
    }

    FutureExecution.async {
      fut.resolve(1)
    }

    sem.wait()

    XCTAssertTrue(fut.isCompleted)
    XCTAssert(res == fut.get())
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testCompletePromiseFutureWithImmediateFuture() {
    let promise = Future<Int>.promise()

    XCTAssertFalse(promise.isCompleted)

    let future = Future.succeeded(1)

    promise.completeWith(future)

    let res = promise.get()

    XCTAssertTrue(promise.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testCompletePromiseFutureWithAsyncFuture() {
    let sem = Semaphore()
    let promise = Future<Int>.promise()

    XCTAssertFalse(promise.isCompleted)

    let future = Future<Int>.async {
      sem.wait()
      return .Success(1)
    }

    promise.completeWith(future)

    XCTAssertFalse(promise.isCompleted)

    sem.signal()

    let res = promise.get()

    XCTAssertTrue(promise.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testCompletePromiseFutureWithCompletedPromiseFuture() {
    let promise1 = Future<Int>.promise()

    XCTAssertFalse(promise1.isCompleted)

    let promise2 = Future<Int>.promise()
    promise2.complete(.Success(1))

    XCTAssertTrue(promise2.isCompleted)

    promise1.completeWith(promise2)

    let res = promise1.get()

    XCTAssertTrue(promise1.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testCompletePromiseFutureWithUncompletedPromiseFuture() {
    let promise1 = Future<Int>.promise()

    XCTAssertFalse(promise1.isCompleted)

    let promise2 = Future<Int>.promise()

    promise1.completeWith(promise2)

    XCTAssertFalse(promise1.isCompleted)

    promise2.complete(.Success(1))

    XCTAssertTrue(promise2.isCompleted)

    let res = promise1.get()

    XCTAssertTrue(promise1.isCompleted)
    XCTAssertEqual(res.description, "Success(1)")
  }

  func testFlatMapCompositionWithSuccess() {
    let fut = Future.succeeded(1)
      .flatMap { Future.succeeded([$0, 2]) }
      .flatMap { Future.succeeded($0 + [3]) }

    XCTAssertEqual(fut.get().description, "Success([1, 2, 3])")
  }

  func testFlatMapCompositionWithFailure() {
    let fut = Future.succeeded(1)
      .flatMap { Future<[Int]>.failed(Error.Deliberate(String($0))) }
      .flatMap { Future.succeeded($0 + [2]) }

    XCTAssertEqual(fut.get().description, "Failure(Deliberate(\"1\"))")
  }

  func testFlatMapCompositionWithThrows() {
    func throwing(e: Int) throws -> Future<[Int]> {
      throw Error.Deliberate(String(e))
    }

    let fut = Future.succeeded(1)
      .flatMap(throwing)
      .flatMap { Future.succeeded($0 + [2]) }

    XCTAssertEqual(fut.get().description, "Failure(Deliberate(\"1\"))")
  }

  func testMapCompositionWithSuccess() {
    let fut = Future.succeeded(1)
      .map { [$0, 2] }
      .map { $0 + [3] }

    XCTAssertEqual(fut.get().description, "Success([1, 2, 3])")
  }

  func testMapCompositionWithFailure() {
    let fut = Future<Int>.failed(Error.Deliberate("42")).map { [$0, 2] }

    XCTAssertEqual(fut.get().description, "Failure(Deliberate(\"42\"))")
  }

  func testMapCompositionWithThrows() {
    func throwing(e: Int) throws -> [Int] {
      throw Error.Deliberate(String(e))
    }

    let fut = Future.succeeded(1)
      .map(throwing)
      .map { $0 + [2] }

    XCTAssertEqual(fut.get().description, "Failure(Deliberate(\"1\"))")
  }

  func testOuterFlatMapCompositionStartingWithImmediateFuture() {
    let sem0 = Semaphore()
    let futS = Future.succeeded(0)
    let fut0: Future<[Int]> = futS.flatMap { e in
      sem0.wait()
      return Future.succeeded([e, 1])
    }

    let sem1 = Semaphore()
    let fut1: Future<[Int]> = fut0.flatMap { e in
      sem1.wait()
      return Future.failed(Error.Deliberate(String(e + [2])))
    }

    let fut2: Future<[Int]> = fut1.flatMap(futureFunCausingFatalError)

    XCTAssertFalse(fut0.isCompleted)

    sem0.signal()
    let res0 = fut0.get()

    XCTAssertTrue(fut0.isCompleted)
    XCTAssertFalse(fut1.isCompleted)
    XCTAssertFalse(fut2.isCompleted)
    XCTAssertEqual(res0.description, "Success([0, 1])")

    sem1.signal()
    let res1 = fut1.get()
    let res2 = fut2.get()

    XCTAssertTrue(fut1.isCompleted)
    XCTAssertTrue(fut2.isCompleted)
    XCTAssertEqual(res1.description, "Failure(Deliberate(\"[0, 1, 2]\"))")
    XCTAssertEqual(res2.description, "Failure(Deliberate(\"[0, 1, 2]\"))")
  }

  func testOuterFlatMapCompositionStartingWithAsyncFuture() {
    let sem0 = Semaphore()
    let fut0 = Future<Int>.async {
      sem0.wait()
      return .Success(0)
    }

    let sem1 = Semaphore()
    let fut1: Future<[Int]> = fut0.flatMap { e in
      sem1.wait()
      return Future.async { .Success([e, 1]) }
    }

    let sem2 = Semaphore()
    let fut2: Future<[Int]> = fut1.flatMap { e in
      sem2.wait()
      return Future.async { .Failure(Error.Deliberate(String(e + [2]))) }
    }

    let fut3: Future<[Int]> = fut2.flatMap(futureFunCausingFatalError)

    XCTAssertFalse(fut0.isCompleted)

    sem0.signal()
    let res0 = fut0.get()

    XCTAssertTrue(fut0.isCompleted)
    XCTAssertFalse(fut1.isCompleted)
    XCTAssertFalse(fut2.isCompleted)
    XCTAssertFalse(fut3.isCompleted)

    XCTAssertEqual(res0.description, "Success(0)")

    sem1.signal()
    let res1 = fut1.get()

    XCTAssertTrue(fut1.isCompleted)
    XCTAssertFalse(fut2.isCompleted)
    XCTAssertFalse(fut3.isCompleted)
    XCTAssertEqual(res1.description, "Success([0, 1])")

    sem2.signal()
    let res2 = fut2.get()
    let res3 = fut3.get()

    XCTAssertTrue(fut2.isCompleted)
    XCTAssertTrue(fut3.isCompleted)
    XCTAssertEqual(res2.description, "Failure(Deliberate(\"[0, 1, 2]\"))")
    XCTAssertEqual(res3.description, "Failure(Deliberate(\"[0, 1, 2]\"))")
  }

  func testInnerFlatMapCompositionStartingWithImmediateFuture() {
    let semOut = Semaphore()
    let semIn = Semaphore()

    var futIn: Future<[Int]>!

    let futOut: Future<[Int]> = Future.succeeded(0).flatMap { e0 in
      futIn = Future.succeeded([e0, 1]).flatMap { e1 in
        semIn.wait()
        return Future<[Int]>.failed(Error.Deliberate(String(e1 + [2]))).flatMap(futureFunCausingFatalError)
      }
      semOut.signal()
      return futIn
    }

    semOut.wait()

    XCTAssertFalse(futOut.isCompleted)
    XCTAssertFalse(futIn.isCompleted)

    semIn.signal()
    futIn.get()

    XCTAssertTrue(futIn.isCompleted)
    XCTAssertEqual(futIn.get().description, "Failure(Deliberate(\"[0, 1, 2]\"))")

    futOut.get()

    XCTAssertTrue(futOut.isCompleted)
    XCTAssertEqual(futOut.get().description, "Failure(Deliberate(\"[0, 1, 2]\"))")
  }

  func testInnerFlatMapCompositionStartingWithAsyncFuture() {
    let semOut = Semaphore()
    let semIn = Semaphore()

    var futIn: Future<[Int]>!

    let futOut: Future<[Int]> = Future.async { .Success(0) }.flatMap { e0 in
      let f: Future<[Int]> = Future.async {
        semOut.wait()
        return .Success([e0, 1])
      }

      futIn = f.flatMap { e1 in
        let f: Future<[Int]> = Future.async { .Failure(Error.Deliberate(String(e1 + [2]))) }
        return f.flatMap(futureFunCausingFatalError)
      }
      semIn.signal()
      return futIn
    }

    semIn.wait()

    XCTAssertFalse(futOut.isCompleted)
    XCTAssertFalse(futIn.isCompleted)

    semOut.signal()
    futIn.get()

    XCTAssertTrue(futIn.isCompleted)
    XCTAssertEqual(futIn.get().description, "Failure(Deliberate(\"[0, 1, 2]\"))")

    futOut.get()

    XCTAssertTrue(futOut.isCompleted)
    XCTAssertEqual(futOut.get().description, "Failure(Deliberate(\"[0, 1, 2]\"))")
  }

  func testComplexFlatMapComposition() {
    let futOut: Future<[Int]> = Future.succeeded(0).flatMap { e0 in
      let futIn0 = Future.succeeded([10]).flatMap { e1 in
        Future.async { .Success(e1 + [11]) }
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

    XCTAssertEqual(futOut.get().description, "Success([0, 10, 11, 20, 21])")
  }
}

private func futureFunCausingFatalError(_: [Int]) -> Future<[Int]> {
  fatalError("must not be called")
}
