import XCTest

class TryTests: XCTestCase {
  func testSuccess() {
    let t = Success(1)

    XCTAssertEqual(t.value!, 1)
    XCTAssertEqual(t.val, 1)
    XCTAssertTrue(t.isSuccess)
    XCTAssertFalse(t.isFailure)
    XCTAssertEqual(t.description, "Success(1)")
  }

  func testFailure() {
    let t = Failure<Int>("2")

    XCTAssert(t.value == nil)
    XCTAssertFalse(t.isSuccess)
    XCTAssertTrue(t.isFailure)
    XCTAssertEqual(t.description, "Failure(2)")
  }

  func testFlatMap() {
    let t0 = Success(1).flatMap { e in Success([e, 2]) }
    let t1: Try<[Int]> = t0.flatMap { e in Failure(toString(e + [3])) }
    let t2 = t1.flatMap { e in Success(e + [4]) }

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure([1, 2, 3])")
    XCTAssertEqual(t2.description, "Failure([1, 2, 3])")
  }

  func testMap() {
    let t0 = Success(1).map { e in [e, 2] }
    let t1: Try<[Int]> = t0.flatMap { e in Failure(toString(e + [3])) }
    let t2 = t1.map { e in e + [4] }

    XCTAssertEqual(t0.description, "Success([1, 2])")
    XCTAssertEqual(t1.description, "Failure([1, 2, 3])")
    XCTAssertEqual(t2.description, "Failure([1, 2, 3])")
  }

  func testLeftIdentityMonadLaw() {
    func newSuccess<T>(x: T) -> Try<T> {
      return Success(x)
    }

    let lhs = Success(1).flatMap(newSuccess)
    let rhs = newSuccess(1)

    // Try<T> does not adopt Equatable protocol, so no equality test with `==`
    XCTAssert(lhs.value! == rhs.value!)
  }

  func testRightIdentityMonadLaw() {
    let lhs = Success(1)
    let rhs = Success(1).flatMap { e in Success(e) }

    // Try<T> does not adopt Equatable protocol, so no equality test with `==`
    XCTAssert(lhs.value! == rhs.value!)
  }

  func testAssociativityMonadLaw() {
    func newSuccessIncrementedBy(by: Int)(val: Int) -> Try<Int> {
      return Success(by + val)
    }

    let t = Success(1)
    let f = newSuccessIncrementedBy(1)
    let g = newSuccessIncrementedBy(2)

    let lhs = t.flatMap(f).flatMap(g)
    let rhs = t.flatMap { x in f(val: x).flatMap(g) }

    // Try<T> does not adopt Equatable protocol, so no equality test with `==`
    XCTAssert(lhs.value! == rhs.value!)
  }
}
