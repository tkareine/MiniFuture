import XCTest

class TryTests: XCTestCase {
  func testSuccess() {
    let t = Try.success(["a", "b"])

    XCTAssert(t.value! == ["a", "b"])
    XCTAssertTrue(t.isSuccess)
    XCTAssertFalse(t.isFailure)
    XCTAssertEqual(t.description, "Success([\"a\", \"b\"])")
    XCTAssertEqual(t.debugDescription, "Success([\"a\", \"b\"])")
  }

  func testFailure() {
    let t = Try<Int>.failure("2")

    XCTAssert(t.value == nil)
    XCTAssertEqual(t.failureDescription!, "2")
    XCTAssertFalse(t.isSuccess)
    XCTAssertTrue(t.isFailure)
    XCTAssertEqual(t.description, "Failure(\"2\")")
    XCTAssertEqual(t.debugDescription, "Failure(\"2\")")
  }

  func testFlatMap() {
    let t0 = Try.success(1).flatMap { e in .success([e, 2]) }
    let t1: Try<[Int]> = t0.flatMap { e in .failure(String(e + [3])) }
    let t2 = t1.flatMap { e in .success(e + [4]) }

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure(\"[1, 2, 3]\")")
    XCTAssertEqual(t2.description, "Failure(\"[1, 2, 3]\")")
  }

  func testMap() {
    let t0 = Try.success(1).map { e in [e, 2] }
    let t1: Try<[Int]> = t0.flatMap { e in .failure(String(e + [3])) }
    let t2 = t1.map { e in e + [4] }

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure(\"[1, 2, 3]\")")
    XCTAssertEqual(t2.description, "Failure(\"[1, 2, 3]\")")
  }

  func testEquality() {
    XCTAssert(Try.success(1) == Try.success(1))
    XCTAssert(Try.success(1) != Try.success(2))
    XCTAssert(Try<Int>.failure("lol") == Try<Int>.failure("lol"))
    XCTAssert(Try<Int>.failure("lol") != Try<Int>.failure("bal"))
    XCTAssert(.success(1) != Try<Int>.failure("lol"))
    XCTAssert(Try<Int>.failure("lol") != .success(1))
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
    let lhs = Try.success(1)
    let rhs = Try.success(1).flatMap { e in .success(e) }

    XCTAssert(lhs == rhs)
  }

  func testAssociativityMonadLaw() {
    func makeSuccessIncrementedBy(by: Int)(val: Int) -> Try<Int> {
      return .success(by + val)
    }

    let t = Try.success(1)
    let f = makeSuccessIncrementedBy(1)
    let g = makeSuccessIncrementedBy(2)

    let lhs = t.flatMap(f).flatMap(g)
    let rhs = t.flatMap { x in f(val: x).flatMap(g) }

    XCTAssert(lhs == rhs)
  }
}
