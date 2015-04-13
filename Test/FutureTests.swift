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
    let fut = Future<Int>.failed("1")

    XCTAssertTrue(fut.isCompleted)  // no need to wait with `get`

    let res = fut.get()

    XCTAssertEqual(fut.get().description, "Failure(\"1\")")
    XCTAssertEqual(fut.description, "ImmediateFuture(Optional(Failure(\"1\")))")
    XCTAssertEqual(fut.debugDescription, "ImmediateFuture(Optional(Failure(\"1\")))")
  }

  func testGetSucceedingAsyncFuture() {
    let sem = Semaphore()
    let fut = Future<Int>.async {
      sem.wait()
      return .success(1)
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
    let fut = Future<Int>.async { .failure("1") }
    let res = fut.get()

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(res.description, "Failure(\"1\")")
    XCTAssertEqual(fut.description, "AsyncFuture(Optional(Failure(\"1\")))")
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

    fut.reject("1")

    XCTAssertTrue(fut.isCompleted)
    XCTAssertEqual(fut.get().description, "Failure(\"1\")")
    XCTAssertEqual(fut.description, "PromiseFuture(Optional(Failure(\"1\")))")
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
    let fut = Future.async { .success(1) }
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
      return Future.failed(toString(e + [2]))
    }

    let fut2: Future<[Int]> = fut1.flatMap { e in
      fatalError("must not be called")
      return Future.succeeded(e + [3])
    }

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
    XCTAssertEqual(res1.description, "Failure(\"[0, 1, 2]\")")
    XCTAssertEqual(res2.description, "Failure(\"[0, 1, 2]\")")
  }

  func testOuterFlatMapCompositionStartingWithAsyncFuture() {
    let sem0 = Semaphore()
    let fut0 = Future<Int>.async {
      sem0.wait()
      return .success(0)
    }

    let sem1 = Semaphore()
    let fut1: Future<[Int]> = fut0.flatMap { e in
      sem1.wait()
      return Future.async { .success([e, 1]) }
    }

    let sem2 = Semaphore()
    let fut2: Future<[Int]> = fut1.flatMap { e in
      sem2.wait()
      return Future.async { .failure(toString(e + [2])) }
    }

    let fut3: Future<[Int]> = fut2.flatMap { e in
      fatalError("must not be called")
      return Future.async { .success(e + [2]) }
    }

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
    XCTAssertEqual(res2.description, "Failure(\"[0, 1, 2]\")")
    XCTAssertEqual(res3.description, "Failure(\"[0, 1, 2]\")")
  }

  func testInnerFlatMapCompositionStartingWithImmediateFuture() {
    let semOut = Semaphore()
    let semIn = Semaphore()

    var futIn: Future<[Int]>!

    let futOut: Future<[Int]> = Future.succeeded(0).flatMap { e0 in
      futIn = Future.succeeded([e0, 1]).flatMap { e1 in
        semIn.wait()
        return Future<[Int]>.failed(toString(e1 + [2])).flatMap { e2 in
          fatalError("must not be called")
          return Future.succeeded(e2 + [3])
        }
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
    XCTAssertEqual(futIn.get().description, "Failure(\"[0, 1, 2]\")")

    futOut.get()

    XCTAssertTrue(futOut.isCompleted)
    XCTAssertEqual(futOut.get().description, "Failure(\"[0, 1, 2]\")")
  }

  func testInnerFlatMapCompositionStartingWithAsyncFuture() {
    let semOut = Semaphore()
    let semIn = Semaphore()

    var futIn: Future<[Int]>!

    let futOut: Future<[Int]> = Future.async { .success(0) }.flatMap { e0 in
      let f: Future<[Int]> = Future.async {
        semOut.wait()
        return .success([e0, 1])
      }

      futIn = f.flatMap { e1 in
        let f: Future<[Int]> = Future.async { .failure(toString(e1 + [2])) }
        return f.flatMap { e2 in
          fatalError("must not be called")
          return Future.succeeded(e2 + [3])
        }
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
    XCTAssertEqual(futIn.get().description, "Failure(\"[0, 1, 2]\")")

    futOut.get()

    XCTAssertTrue(futOut.isCompleted)
    XCTAssertEqual(futOut.get().description, "Failure(\"[0, 1, 2]\")")
  }

  func testComplexFlatMapComposition() {
    let futOut: Future<[Int]> = Future.succeeded(0).flatMap { e0 in
      let futIn0 = Future.succeeded([10]).flatMap { e1 in
        Future.async { .success(e1 + [11]) }
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

  func testMapCompositionWithSuccess() {
    let fut = Future.succeeded(1).map { [$0, 2] }
    XCTAssertEqual(fut.get().description, "Success([1, 2])")
  }

  func testMapCompositionWithFailure() {
    let fut = Future<Int>.failed("1").map { [$0, 2] }
    XCTAssertEqual(fut.get().description, "Failure(\"1\")")
  }
}
