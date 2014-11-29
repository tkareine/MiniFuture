ToyFuture
=========

A Future design pattern implementation in Swift using libdispatch and
POSIX mutexes and condition variables. It's an experiment, thus the
name. *Don't use in production!*

Characteristics
---------------

We use `Try<T>` and its two concrete subclass implementations,
`Success<T>` and `Failure<T>` as helpers. The first is meant for the
caller of the Future to signify successful computation. The result of
the computation is wrapped inside the object. The latter sublass
signifies computation failure, and you can describe the failure in the
object as a string.

Future composition with `Future#flatMap` either continues the
composition chain or short-circuits based on the resolved `Try<T>`
object of the current future.

We must use explicit success and failure objects, because you can't
use exceptions in Swift. The idea is inspired from Scala 2.10, where
the Future library wraps exceptions thrown inside future computations
to `Failure` values. In ToyFuture, you must do this yourself.

All async operations run in libdispatch's default global concurrent
queue. Closures passed to `Future#flatMap` and `Future#onComplete`
always execute in a queue worker thread.  Use synchronization as
appropriate when accessing objects outside the Future.

For wrapping values inside the Future, use `Future.succeeded` and
`Future.failed` for immediate values. Use `Future.async` for async
jobs that compute the value later in a queue worker thread.

Example
-------

```swift
let futBegin = Future.async { Success(0) }
let futEnd: Future<[Int]> = futBegin.flatMap { e0 in
  let futIn0 = Future.succeeded(10).flatMap { e1 in
    Future.async { Success([e1] + [11]) }
  }

  let futIn1 = Future.succeeded([20]).flatMap {
    Future.succeeded($0 + [21])
  }

  return futIn0.flatMap { e1 in
    return futIn1.flatMap { e2 in
      Future.succeeded([e0] + e1 + e2)
    }
  }
}

futBegin.get()  // Success(0)
futEnd.get()    // Success([0, 10, 11, 20, 21])
```

See more in `ToyFutureExample/main.swift`.

Performance
-----------

There's a benchmark in `ToyFutureBenchmark/main.swift`. It builds
complex nested futures (`futEnd` variable in the code) in a loop
`NumberOfFlatMapChains` times and composes them into one huge composed
future (`fut` variable). Then it waits for the results.

We repeat this `NumberOfIterations` times to get the arithmetic
average and standard deviation of the completion of each huge future.

Compile it with Release build configuration, using -O compiler
flag. Then run it from the terminal.

Example run on my laptop (MacBook Pro 2,6 GHz Intel Core i7 Haswell,
16 GB 1600 MHz DDR3):

```
$ ./ToyFutureBenchmark
warm up: 2.07 s (± 0.01 s)
measure: 2.07 s (± 0.01 s)
```

Total memory consumption stayed below 60 MB.

Future work
-----------

* Should `Try<T>` be replaced with `Either<L, R>`, so the client could
  decide the type for failure cases?
* Implement cancellation and timeouts
* Implement more composition operations
