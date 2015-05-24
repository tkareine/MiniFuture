import Dispatch

public final class Semaphore {
  public typealias TimeoutInMS = dispatch_time_t

  private let sem: dispatch_semaphore_t

  public init(count: Int = 0) {
    sem = dispatch_semaphore_create(count)
  }

  public func signal() {
    dispatch_semaphore_signal(sem)
  }

  public func wait(timeout timeoutInMS: TimeoutInMS = DISPATCH_TIME_FOREVER) {
    let timeoutInNS = timeoutInMS != DISPATCH_TIME_FOREVER
      ? dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_MSEC) * Int64(timeoutInMS))
      : DISPATCH_TIME_FOREVER

    dispatch_semaphore_wait(sem, timeoutInNS)
  }
}
