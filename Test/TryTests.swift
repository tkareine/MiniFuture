import XCTest

#if SWIFT_PACKAGE
  import MiniFuture
#endif

class TryTests: XCTestCase {
  func testSuccess() {
    let t = Try.success(["a", "b"])

    XCTAssert(try! t.value() == ["a", "b"])
    XCTAssertTrue(t.isSuccess)
    XCTAssertFalse(t.isFailure)
    XCTAssertEqual(t.description, "Try.success([\"a\", \"b\"])")
    XCTAssertEqual(t.debugDescription, "Try.success([\"a\", \"b\"])")
  }

  func testFailure() {
    let t = Try<Int>.failure(AppError.deliberate("42"))

    do {
      let _ = try t.value()
      XCTFail("should have thrown")
    } catch AppError.deliberate(let err) {
      XCTAssert(err == "42")
    } catch {
      XCTFail("should have been catched")
    }

    XCTAssertFalse(t.isSuccess)
    XCTAssertTrue(t.isFailure)
    XCTAssertEqual(t.description, "Try.failure(AppError.deliberate(\"42\"))")
    XCTAssertEqual(t.debugDescription, "Try.failure(AppError.deliberate(\"42\"))")
  }

  func testFlatMapComposition() {
    let t0 = Try.success(1).flatMap { e in .success([e, 2]) }
    let t1: Try<[Int]> = t0.flatMap { e in .failure(AppError.deliberate(String(describing: e + [3]))) }
    let t2 = t1.flatMap(tryFunCausingFatalError)

    XCTAssertEqual(t0.description, "Try.success([1, 2])")
    XCTAssertEqual(t1.description, "Try.failure(AppError.deliberate(\"[1, 2, 3]\"))")
    XCTAssertEqual(t2.description, "Try.failure(AppError.deliberate(\"[1, 2, 3]\"))")
  }

  func testFlatMapThrows() {
    let t: Try<[Int]> = Try.success(1).flatMap { e in throw AppError.deliberate(String(describing: [e, 2])) }

    XCTAssertEqual(t.description, "Try.failure(AppError.deliberate(\"[1, 2]\"))")
  }

  func testMapComposition() {
    let t0 = Try.success(1).map { e in [e, 2] }
    let t1: Try<[Int]> = t0.flatMap { e in .failure(AppError.deliberate(String(describing: e + [3]))) }
    let t2 = t1.map(funCausingFatalError)

    XCTAssertEqual(t0.description, "Try.success([1, 2])")
    XCTAssertEqual(t1.description, "Try.failure(AppError.deliberate(\"[1, 2, 3]\"))")
    XCTAssertEqual(t2.description, "Try.failure(AppError.deliberate(\"[1, 2, 3]\"))")
  }

  func testMapThrows() {
    let t: Try<[Int]> = Try.success(1).map { e in throw AppError.deliberate(String(describing: [e, 2])) }

    XCTAssertEqual(t.description, "Try.failure(AppError.deliberate(\"[1, 2]\"))")
  }

  func testEquality() {
    XCTAssert(Try.success(1) == Try.success(1))
    XCTAssert(Try.success(1) != Try.success(2))
    XCTAssert(Try<Int>.failure(AppError.deliberate("lol")) == Try<Int>.failure(AppError.deliberate("lol")))
    XCTAssert(Try<Int>.failure(AppError.deliberate("lol")) == Try<Int>.failure(AppError.deliberate("bal")))
    XCTAssert(Try<Int>.failure(AppError.deliberate("lol")) != Try<Int>.failure(AppError.unsupported))
    XCTAssert(Try.success(1) != Try<Int>.failure(AppError.deliberate("1")))
    XCTAssert(Try<Int>.failure(AppError.deliberate("1")) != Try.success(1))
  }

  func testLeftIdentityMonadLaw() {
    func makeSuccess(_ x: Int) -> Try<Int> {
      return .success(x)
    }

    let lhs = Try.success(1).flatMap(makeSuccess)
    let rhs = makeSuccess(1)

    XCTAssert(lhs == rhs)
  }

  func testRightIdentityMonadLaw() {
    let lhs = Try.success(1)
    let rhs = Try.success(1).flatMap { e in .success(e) }

    XCTAssert(lhs == rhs)
  }

  func testAssociativityMonadLaw() {
    func makeSuccessIncrementedBy(_ by: Int) -> (Int) -> Try<Int> {
      return { val in .success(by + val) }
    }

    let t = Try.success(1)
    let f = makeSuccessIncrementedBy(1)
    let g = makeSuccessIncrementedBy(2)

    let lhs = t.flatMap(f).flatMap(g)
    let rhs = t.flatMap { x in f(x).flatMap(g) }

    XCTAssert(lhs == rhs)
  }
}

private func tryFunCausingFatalError(_: [Int]) -> Try<[Int]> {
  fatalError("must not be called")
}

private func funCausingFatalError(_: [Int]) -> [Int] {
  fatalError("must not be called")
}
