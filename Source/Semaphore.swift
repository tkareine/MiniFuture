import Dispatch

public final class Semaphore {
  public typealias TimeoutInMS = UInt64

  private let sem: DispatchSemaphore

  public init(count: Int = 0) {
    sem = DispatchSemaphore(value: count)
  }

  public func signal() {
    sem.signal()
  }

  public func wait(timeout timeoutInMS: TimeoutInMS = UInt64.max) {
    let timeout = timeoutInMS != UInt64.max
      ? DispatchTime(uptimeNanoseconds: NSEC_PER_MSEC * timeoutInMS)
      : DispatchTime.distantFuture

    let _ = sem.wait(timeout: timeout)
  }
}
