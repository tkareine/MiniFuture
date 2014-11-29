import Dispatch

public class Semaphore {
  private var sem: dispatch_semaphore_t

  public init(count: Int = 0) {
    sem = dispatch_semaphore_create(count)
  }

  public func signal() {
    dispatch_semaphore_signal(sem)
  }

  public func wait() {
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER)
  }
}
