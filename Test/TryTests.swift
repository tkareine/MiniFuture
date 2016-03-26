import XCTest

class TryTests: XCTestCase {
  func testSuccess() {
    let t = Try.Success(["a", "b"])

    XCTAssert(try! t.value() == ["a", "b"])
    XCTAssertTrue(t.isSuccess)
    XCTAssertFalse(t.isFailure)
    XCTAssertEqual(t.description, "Success([\"a\", \"b\"])")
    XCTAssertEqual(t.debugDescription, "Success([\"a\", \"b\"])")
  }

  func testFailure() {
    let t = Try<Int>.Failure(Error.Deliberate("42"))

    do {
      try t.value()
      XCTFail("should have thrown")
    } catch Error.Deliberate(let err) {
      XCTAssert(err == "42")
    } catch {
      XCTFail("should have been catched")
    }

    XCTAssertFalse(t.isSuccess)
    XCTAssertTrue(t.isFailure)
    XCTAssertEqual(t.description, "Failure(Deliberate(\"42\"))")
    XCTAssertEqual(t.debugDescription, "Failure(Deliberate(\"42\"))")
  }

  func testFlatMapComposition() {
    let t0 = Try.Success(1).flatMap { e in .Success([e, 2]) }
    let t1: Try<[Int]> = t0.flatMap { e in .Failure(Error.Deliberate(String(e + [3]))) }
    let t2 = t1.flatMap(tryFunCausingFatalError)

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure(Deliberate(\"[1, 2, 3]\"))")
    XCTAssertEqual(t2.description, "Failure(Deliberate(\"[1, 2, 3]\"))")
  }

  func testFlatMapThrows() {
    let t: Try<[Int]> = Try.Success(1).flatMap { e in throw Error.Deliberate(String([e, 2])) }

    XCTAssertEqual(t.description, "Failure(Deliberate(\"[1, 2]\"))")
  }

  func testMapComposition() {
    let t0 = Try.Success(1).map { e in [e, 2] }
    let t1: Try<[Int]> = t0.flatMap { e in .Failure(Error.Deliberate(String(e + [3]))) }
    let t2 = t1.map(funCausingFatalError)

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure(Deliberate(\"[1, 2, 3]\"))")
    XCTAssertEqual(t2.description, "Failure(Deliberate(\"[1, 2, 3]\"))")
  }

  func testMapThrows() {
    let t: Try<[Int]> = Try.Success(1).map { e in throw Error.Deliberate(String([e, 2])) }

    XCTAssertEqual(t.description, "Failure(Deliberate(\"[1, 2]\"))")
  }

  func testEquality() {
    XCTAssert(Try.Success(1) == Try.Success(1))
    XCTAssert(Try.Success(1) != Try.Success(2))
    XCTAssert(Try<Int>.Failure(Error.Deliberate("lol")) == Try<Int>.Failure(Error.Deliberate("lol")))
    XCTAssert(Try<Int>.Failure(Error.Deliberate("lol")) == Try<Int>.Failure(Error.Deliberate("bal")))
    XCTAssert(Try<Int>.Failure(Error.Deliberate("lol")) != Try<Int>.Failure(Error.Unsupported))
    XCTAssert(Try.Success(1) != Try<Int>.Failure(Error.Deliberate("1")))
    XCTAssert(Try<Int>.Failure(Error.Deliberate("1")) != Try.Success(1))
  }

  func testLeftIdentityMonadLaw() {
    func newSuccess(x: Int) -> Try<Int> {
      return .Success(x)
    }

    let lhs = Try.Success(1).flatMap(newSuccess)
    let rhs = newSuccess(1)

    XCTAssert(lhs == rhs)
  }

  func testRightIdentityMonadLaw() {
    let lhs = Try.Success(1)
    let rhs = Try.Success(1).flatMap { e in .Success(e) }

    XCTAssert(lhs == rhs)
  }

  func testAssociativityMonadLaw() {
    func makeSuccessIncrementedBy(by: Int) -> (Int) -> Try<Int> {
      return { val in .Success(by + val) }
    }

    let t = Try.Success(1)
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
