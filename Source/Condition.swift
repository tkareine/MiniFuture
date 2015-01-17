import Dispatch  // for pthread

class Condition {
  private let mutex: UnsafeMutablePointer<pthread_mutex_t>
  private let condition: UnsafeMutablePointer<pthread_cond_t>

  typealias WaitCallback = () -> Void

  private lazy var waitCallback: WaitCallback = { [unowned self] in self.wait() }

  init() {
    mutex = UnsafeMutablePointer.alloc(1)
    let mutexRes = pthread_mutex_init(mutex, nil)
    assert(mutexRes == 0)
    condition = UnsafeMutablePointer.alloc(1)
    let condRes = pthread_cond_init(condition, nil)
    assert(condRes == 0)
  }

  deinit {
    let condRes = pthread_cond_destroy(condition)
    assert(condRes == 0)
    condition.dealloc(1)
    let mutexRes = pthread_mutex_destroy(mutex)
    assert(mutexRes == 0)
    mutex.dealloc(1)
  }

  func synchronized<T>(block: (WaitCallback) -> T) -> T {
    lock()
    let ret = block(waitCallback)
    unlock()
    return ret
  }

  func signal() {
    let res = pthread_cond_signal(condition)
    assert(res == 0)
  }

  private func lock() {
    let res = pthread_mutex_lock(mutex)
    assert(res == 0)
  }

  private func unlock() {
    let res = pthread_mutex_unlock(mutex)
    assert(res == 0)
  }

  private func wait() {
    let res = pthread_cond_wait(condition, mutex)
    assert(res == 0)
  }
}
