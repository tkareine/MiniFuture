# MiniFuture

A monadic Future design pattern implementation in Swift language, using
[libdispatch](http://libdispatch.macosforge.org/) and POSIX mutexes and
condition variables. Design inspired from Scala's
[scala.concurrent.Future](http://www.scala-lang.org/api/current/#scala.concurrent.Future).

Only the essential features are in place currently. We're using the library in
production, and it appears to work as expected. There's a benchmark that acts
as a stress test, see [Performance](#performance) below.

[![Pod version](https://badge.fury.io/co/MiniFuture.svg)][MiniFuturePod]
[![Build status](https://secure.travis-ci.org/tkareine/MiniFuture.svg)][MiniFutureBuild]

## Requirements

* iOS >= 7.0 (if installing by copying source files manually) or iOS >= 8.0
  (if installing as embedded framework)
* Mac OS X >= 10.9
* Xcode >= 7.0 (Swift 2)

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org/) is a centralized dependency manager for
Cocoa libraries. It integrates libraries as embedded frameworks to your
project. This requires that the minimum deployment target of your project is
iOS 8.0 or OS X 10.9.

MiniFuture is available as a [pod][MiniFuturePod]. Add the following line to
your project's `Podfile` in order to have the library as a dependency:

```ruby
pod 'MiniFuture', '~> 0.5.0'
```

And run `pod install`.

In your source code, `import MiniFuture` to use the library.

### Manually

Copy all files under `Source` directory to your project. You have to figure
out how to upgrade the library yourself.

## Characteristics

A future is a promise of a computation that will complete eventually. We use
`Try<T>` value type to wrap these computation results. It's an enumeration
with two members, `Success<T>` and `Failure<ErrorType>`. The first is meant
for the caller of the Future to signify successful computation, with the
result of the computation as the associated value of type `T`. The latter
member signifies computation failure, with `ErrorType` as the associated
value.

For example, the following future will complete with `.Success(1)` eventually:

```swift
let fut = Future<Int>.async {
  NSThread.sleepForTimeInterval(0.2)
  return .Success(1)
}

assert(succeeded.get() == .Success(1))
```

The basic operation to compose Futures is with `Future#flatMap(_:)`. The
method signature is:

```swift
flatMap<U>(f: T throws -> Future<U>) -> Future<U>
```

It takes in a closure, `f`. If the current future completes with a success
value, `f` gets called with `T` as its argument. The return value of `f` is
the next future computation. Later, if that future completes with a success
value, the closure passed to that future gets called. This is the asynchronous
call chain of the futures.

If the current future completes with a failure value, `f` will not be
called. This short-circuits the call chain of the futures.

The closure `f` may throw an error when called. If that happens, the return
value of `f` will be a future completed with a failure value containing the
error.

For example:

```swift
enum Error: ErrorType {
  case Deliberate(String)
}

let fut: Future<[Int]> = Future.async { .Success(0) }
  .flatMap { Future.succeeded([$0, 1]) }
  .flatMap { throw Error.Deliberate(String($0)) }
  .flatMap { Future.succeeded($0 + [2]) }

assert(String(fut.get()) == "Failure(Deliberate(\"[0, 1]\"))")
```

`Try<T>` and the automatic handling of thrown errors is borrowed from Scala
2.10.

All asynchronous operations run in libdispatch's default global concurrent
queue. Closures passed to `Future#flatMap(_:)`, `Future#map(_:)`,
`Future#onComplete(_:)`, and `Future.async(_:)` are always executed in a queue
worker thread. Use proper synchronization when accessing shared state via
references captured in the closures.

## Usage

To get a Future job running, use `Future.succeeded(_:)` and
`Future.failed(_:)` to wrap immediate values. These return `ImmediateFuture`
objects, a Future implementation class already completed with success or
failure value.

Use `Future.async(_:)` for asynchronous jobs that compute the value later in a
queue worker thread. You pass a block to `async(_:)` and return either a
`Success<T>` or `Failure<ErrorType>` value from it. The Future implementation
class here is `AsyncFuture`.

For adapting existing asynchronous interfaces with Futures, use
`Future.promise(_:)`. This returns a `PromiseFuture` object, a promise kind of
Future implementation class. Pass the Future to an existing asynchronous
interface, and in the completion handler of the interface, complete the Future
with success (`Future#resolve(_:)`) or failure (`Future#reject(_:)`). You can
immediately return a `PromiseFuture` to code expecting Futures and let the
`PromiseFuture` object complete later.

You can complete a `PromiseFuture` with the result of another future,
too. Call `PromiseFuture#completeWith(_:)`, passing another future as
the argument. Once the future completes, the promise completes with
the same result as the future.

When you get a handle to a Future, use `Future#flatMap(_:)` or
`Future#map(_:)` to compose another Future that depends on the completed
result of the previous Future. Use `Future#get()` to wait for the result of a
Future. Use `Future#onComplete(_:)` to add a callback for side-effects to be
run when the Future completes.

### Example

```swift
extension String {
  var trimmed: String {
    return stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
  }

  func excerpt(maxLength: Int) -> String {
    precondition(maxLength >= 0, "maxLength must be positive")

    if maxLength == 0 {
      return ""
    }

    let length = characters.count

    if length <= maxLength {
      return self
    }

    return self[startIndex..<startIndex.advancedBy(maxLength-1)].trimmed + "…"
  }
}

/**
 * Request a web resource asynchronously, immediately returning a handle to
 * the job as a promise kind of Future. When NSURLSession calls the completion
 * handler, we fullfill the promise. If the completion handler gets called
 * with the contents of the web resource, we resolve the promise with the
 * contents (the success case). Otherwise, we reject the promise with failure.
 */
func loadURL(url: NSURL) -> Future<NSData> {
  let promise = Future<NSData>.promise()
  let task = NSURLSession.sharedSession().dataTaskWithURL(url, completionHandler: { data, response, error in
    if let err: NSError = error {
      promise.reject(err)
    } else if let d = data {
      promise.resolve(d)
    } else {
      promise.reject(Error.FailedLoadingURL(url))
    }
  })
  task.resume()
  return promise
}

/**
 * Parse data as HTML document, finding specific contents from it with an
 * XPath query. We return a completed Future as the handle to the result. If
 * we can parse the data as an HTML document and the query succeeds, we return
 * a successful Future with the query result. Otherwise, we return failed
 * Future describing the error.
 *
 * Because this function gets called inside `Future#flatMap`, it's run in
 * background in a queue worker thread.
 */
func readXPathFromHTML(xpath: String, data: NSData) throws -> Future<HTMLNode> {
  let doc = try HTMLDocument.readDataAsUTF8(data)
  let node = try doc.rootHTMLNode()
  let found = try node.nodeForXPath(xpath)
  return Future.succeeded(found)
}

let wikipediaURL = NSURL(string: "https://en.wikipedia.org/wiki/Main_Page")!
let featuredArticleXPath = "//*[@id='mp-tfa']"

let result = loadURL(wikipediaURL)
  /* Future composition (chaining): when this Future completes successfully,
   * pass its result to a function that does more work, returning another
   * Future. If this Future completes with failure, the chain short-circuits
   * and further flatMap methods are not called. Calls to flatMap are always
   * executed in a queue worker thread.
   */
  .flatMap { try readXPathFromHTML(featuredArticleXPath, data: $0) }
  /* Wait for Future chain to complete. This acts as a synchronization point.
   */
  .get()

switch result {
case .Success(let value):
  let excerpt = value.textContents!.excerpt(78)
  print("Excerpt from today's featured article at Wikipedia: \(excerpt)")
case .Failure(let error):
  print("Error getting today's featured article from Wikipedia: \(error)")
}
```

See more in `Example/main.swift`. You can run the examples:

```
$ make example
# xcodebuild output…

./build/Example
Excerpt from today's featured article at Wikipedia: Upper and Lower Table Rock are two prominent volcanic plateaus just north of…
```

## Performance

There's a benchmark in `Benchmark/main.swift`. It builds up complex nested
Futures (the `futEnd` variable in the code) in a loop 2000 times
(`NumberOfFutureCompositions`) and chains them into one big composite Future
(the `fut` variable). Then the benchmark waits for the Future to complete.

We repeat this 500 times (`NumberOfIterations`) to get the arithmetic mean and
standard deviation of time spent completing each composite Future.

Compile it with Release build configuration, which enables `-O` compiler
flag. Then run it from the terminal.

Example run with MacBook Pro 2.6 GHz Intel Core i7 Haswell, 16 GB 1600 MHz
DDR3:

```
$ make benchmark
# xcodebuild output…

./build/Benchmark
iterations: 500, futures composed: 2000

warm up: 65 ms (± 4 ms)
measure: 65 ms (± 3 ms)

Apple Swift version 2.2 (swiftlang-703.0.18.1 clang-703.0.29)
Target: x86_64-apple-macosx10.9
```

Total memory consumption of the process stayed below 15 MB.

## Future work

* Implement Future cancellation and timeouts
* Implement more composition operations on Futures

## License

MiniFuture is released under the MIT license. See `LICENSE.txt` for details.

[MiniFuturePod]: https://cocoapods.org/pods/MiniFuture
[MiniFutureBuild]: https://travis-ci.org/tkareine/MiniFuture
