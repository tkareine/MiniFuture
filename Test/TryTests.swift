import XCTest

class TryTests: XCTestCase {
  func testSuccess() {
    let t = Try.Success(["a", "b"])

    XCTAssert(t.value! == ["a", "b"])
    XCTAssertTrue(t.isSuccess)
    XCTAssertFalse(t.isFailure)
    XCTAssertEqual(t.description, "Success([a, b])")
    XCTAssertEqual(t.debugDescription, "Success([\"a\", \"b\"])")
  }

  func testFailure() {
    let t = Try<Int>.Failure("2")

    XCTAssert(t.value == nil)
    XCTAssertEqual(t.failureDescription!, "2")
    XCTAssertFalse(t.isSuccess)
    XCTAssertTrue(t.isFailure)
    XCTAssertEqual(t.description, "Failure(\"2\")")
    XCTAssertEqual(t.debugDescription, "Failure(\"2\")")
  }

  func testFlatMap() {
    let t0 = Try.Success(1).flatMap { e in .Success([e, 2]) }
    let t1: Try<[Int]> = t0.flatMap { e in .Failure(toString(e + [3])) }
    let t2 = t1.flatMap { e in .Success(e + [4]) }

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure(\"[1, 2, 3]\")")
    XCTAssertEqual(t2.description, "Failure(\"[1, 2, 3]\")")
  }

  func testMap() {
    let t0 = Try.Success(1).map { e in [e, 2] }
    let t1: Try<[Int]> = t0.flatMap { e in .Failure(toString(e + [3])) }
    let t2 = t1.map { e in e + [4] }

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure(\"[1, 2, 3]\")")
    XCTAssertEqual(t2.description, "Failure(\"[1, 2, 3]\")")
  }

  func testEquality() {
    XCTAssert(Try.Success(1) == Try.Success(1))
    XCTAssert(Try.Success(1) != Try.Success(2))
    XCTAssert(Try<Int>.Failure("lol") == Try<Int>.Failure("lol"))
    XCTAssert(Try<Int>.Failure("lol") != Try<Int>.Failure("bal"))
    XCTAssert(.Success(1) != Try<Int>.Failure("lol"))
    XCTAssert(Try<Int>.Failure("lol") != .Success(1))
  }

  func testLeftIdentityMonadLaw() {
    func newSuccess<T>(x: T) -> Try<T> {
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
    func makeSuccessIncrementedBy(by: Int)(val: Int) -> Try<Int> {
      return .Success(by + val)
    }

    let t = Try.Success(1)
    let f = makeSuccessIncrementedBy(1)
    let g = makeSuccessIncrementedBy(2)

    let lhs = t.flatMap(f).flatMap(g)
    let rhs = t.flatMap { x in f(val: x).flatMap(g) }

    XCTAssert(lhs == rhs)
  }
}
