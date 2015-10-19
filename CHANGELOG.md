# 0.3.0 / 2015-10-19

* Update code for Swift 2.0
* Simplify pattern matching for `Try<T>.Success` by removing value
  boxing workaround for the associated value
* Use `ErrorType` instead of `String` for the associated value of
  `Try<T>.Failure`. This enables using `NSError`s for failures.
* Remove `Try.success` and `Try.failure` static factory functions as
  unnecessary
* Handle thrown exceptions inside the closures of `Future#flatMap(_:)`
  and `Future#map(_:)`

# 0.2.0 / 2015-04-19

* Update code for Swift 1.2
* Backwards incompatible change: now `Try<T>.Success` contains its
  associated value inside a `Box` helper object. This affects how
  you create a new `Success` value and access its associated value:

```swift
func getTry<T>(x: T) -> Try<T> {
  return .success(x)
}

switch getTry(42) {
case .Success(let box):
  println("succeeded: \(box.value)")
case .Failure(let desc):
  println("failed: \(desc)")
}
```

* Performance improvement: the change of `Try<T>.Success` described
  above together with Swift 1.2 decreased the execution time of the
  project's benchmark. One iteration in the benchmark takes now about
  ¼th of the time compared to project version 0.1.0 compiled with
  Swift 1.1.

# 0.1.0 / 2015-03-01

* First release
