import XCTest

class SemaphoreTests: XCTestCase {
  func testWaitWithTimeout() {
    let expectation = expectationWithDescription("wait with timeout")
    FutureExecution.dispatchAsync {
      Semaphore().wait(timeout: 50)
      expectation.fulfill()
    }
    waitForExpectationsWithTimeout(0.2, handler: nil)
  }

  func testWaitAndSignal() {
    let sem = Semaphore()
    let expectation = expectationWithDescription("wait and signal")
    FutureExecution.dispatchAsync {
      sem.wait()
      expectation.fulfill()
    }
    sem.signal()
    waitForExpectationsWithTimeout(0.1, handler: nil)
  }
}
