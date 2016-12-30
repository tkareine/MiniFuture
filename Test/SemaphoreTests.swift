import XCTest

class SemaphoreTests: XCTestCase {
  func testWaitWithTimeout() {
    let expect = expectation(description: "wait with timeout")
    FutureExecution.async {
      Semaphore().wait(timeout: 50)
      expect.fulfill()
    }
    waitForExpectations(timeout: 0.2, handler: nil)
  }

  func testWaitAndSignal() {
    let sem = Semaphore()
    let expect = expectation(description: "wait and signal")
    FutureExecution.async {
      sem.wait()
      expect.fulfill()
    }
    sem.signal()
    waitForExpectations(timeout: 0.1, handler: nil)
  }
}
