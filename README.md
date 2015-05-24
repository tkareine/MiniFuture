# MiniFuture

A monadic Future design pattern implementation in Swift language,
using [libdispatch](http://libdispatch.macosforge.org/) and POSIX
mutexes and condition variables. Design inspired from Scala's
[scala.concurrent.Future](http://www.scala-lang.org/api/current/#scala.concurrent.Future).

Only the essential features are in place currently. We're using the
library in production, and it appears to work as expected. There's a
benchmark that acts as a stress test, see [Performance](#performance)
below.

[![Pod version](https://badge.fury.io/co/MiniFuture.svg)](http://badge.fury.io/co/MiniFuture)

## Requirements

* For iOS: >= 7.0 (if installing by copying source files manually) or >=
  8.0 (if installing as embedded framework)
* For Mac OS X: >= 10.9
* Xcode 6.3

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org/) is a centralized dependency manager
for Cocoa libraries. It integrates libraries as embedded frameworks to
your project. This requires that the minimum deployment target of your
project is iOS 8.0 or OS X 10.9.

To add MiniFuture to your project, add the following line to your
`Podfile`:

```ruby
pod 'MiniFuture'
```

And run `pod install`.

In your source code, `import MiniFuture` to use the library.

### Manually

Copy all files under `Source` directory to your project. You have to
figure out how to upgrade the library yourself.

## Characteristics

We use `Try<T>` value type to wrap computation results. It's an
enumeration with two members, `Success` and `Failure`. The first is
meant for the caller of the Future to signify successful computation,
with the result of the computation as the associated value of type
`T`. The latter member signifies computation failure. You describe the
failure with the associated String value.

Future composition with `Future#flatMap` either continues the
composition chain or short-circuits based on the resolved `Try<T>`
value of the current Future. A `Success` value continues the chain,
calling the next `flatMap` operation. A `Failure` value returns
immediately, skipping further calls to `flatMap`, and returns the
value as the result of the composed Future.

We use explicit success and failure values, because you can't use
exceptions in Swift. The idea is inspired from Scala 2.10, where the
Future library wraps exceptions thrown inside Future computations to
`Failure` values. In MiniFuture, you must denote failures as values.

All asynchronous operations run in libdispatch's default global
concurrent queue. Closures passed to `Future#flatMap`, `Future#map`,
`Future#onComplete`, and `Future.async` always execute in a queue
worker thread. Use synchronization as appropriate when accessing
shared state outside the closures.

## Usage

To get a Future job running, use `Future.succeeded` and
`Future.failed` to wrap immediate values. These return
`ImmediateFuture` objects, a Future implementation class already
completed with success or failure value.

Use `Future.async` for asynchronous jobs that compute the value later
in a queue worker thread. You pass a block to `Future.async` and
return either a `Success` or `Failure` value from it. The Future
implementation class here is `AsyncFuture`.

For adapting existing asynchronous interfaces with Futures, use
`Future.promise`. This returns a `PromiseFuture` object, a promise
kind of Future implementation class. Pass the Future to an existing
asynchronous interface, and in the completion handler of the
interface, complete the Future with success (`Future#resolve`) or
failure (`Future#reject`). You can immediately return a
`PromiseFuture` to code expecting Futures and let the `PromiseFuture`
object complete later.

When you get a handle to a Future, use `Future#flatMap` or
`Future#map` to compose another Future that depends on the completed
result of the previous Future. Use `Future#get` to wait for the result
of a Future. Use `Future#onComplete` to add a callback for
side-effects to be run when the Future completes.

### Example

```swift
extension String {
  func excerpt(maxLength: Int) -> String {
    let length = count(self)

    if length <= maxLength {
      return self
    }

    let idx = advance(self.startIndex, maxLength)
    return self[Range(start: self.startIndex, end: idx)] + "…"
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
    if error != nil {
      promise.reject("failed loading URL: \(url)")
    } else if let d = data {
      promise.resolve(d)
    } else {
      promise.reject("unknown error at loading URL: \(url)")
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
func readXPathFromHTML(xpath: String, data: NSData) -> Future<HTMLNode> {
  var err: NSError?

  if let doc = HTMLDocument.readDataAsUTF8(data, error: &err),
         node = doc.rootHTMLNode(&err),
         found = node.nodeForXPath(xpath, error: &err) {
    return Future.succeeded(found)
  }

  if let e = err {
    return Future.failed("failed parsing HTML: \(e)")
  } else {
    return Future.failed("unknown error at parsing HTML")
  }
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
  .flatMap { readXPathFromHTML(featuredArticleXPath, $0) }
  /* Wait for Future chain to complete. This acts as a synchronization point.
   */
  .get()

switch result {
case .Success(let box):
  let excerpt = box.value.textContents!.excerpt(72)
  println("Excerpt from today's featured article at Wikipedia: \(excerpt)")
case .Failure(let desc):
  println("Error getting today's featured article from Wikipedia: \(desc)")
}
```

See more in `Example/main.swift`. You can run the examples:

```
$ make example
# xcodebuild output…

./build/Example
Excerpt from today's featured article at Wikipedia: Casino Royale (1953) is a James Bond novel, the first of twelve featurin…
```

### Reject `PromiseFuture` with `NSError`

Being a pure Swift implementation, MiniFuture does not depend on
Foundation classes. This is why a `Failure` value contains just a
string description of the failure case. The other motivation is that
strings are simpler to use than `NSError` objects.

You can use extensions to make MiniFuture easier to use with
`NSError`s. For example, to reject a `PromiseFuture` with an
`NSError`:

```swift
import Foundation
import MiniFuture

extension PromiseFuture {
  func reject(error: NSError) {
    reject("\(error.localizedDescription) (\(error.code))")
  }
}
```

## Performance

There's a benchmark in `Benchmark/main.swift`. It builds up complex
nested Futures (the `futEnd` variable in the code) in a loop 2000
times (`NumberOfFutureCompositions`) and chains them into one big
composite Future (the `fut` variable). Then the benchmark waits for
the Future to complete.

We repeat this 500 times (`NumberOfIterations`) to get the arithmetic
mean and standard deviation of time spent completing each composite
Future.

Compile it with Release build configuration, which enables `-O`
compiler flag. Then run it from the terminal.

Example run with MacBook Pro 2.6 GHz Intel Core i7 Haswell, 16 GB 1600
MHz DDR3:

```
$ make benchmark
# xcodebuild output…

./build/Benchmark
iterations: 500, futures composed: 2000

warm up: 44 ms (± 4 ms)
measure: 44 ms (± 5 ms)

Apple Swift version 1.2 (swiftlang-602.0.53.1 clang-602.0.53)
Target: x86_64-apple-darwin14.3.0
```

Total memory consumption of the process stayed below 50 MB.

## Future work

* Implement Future cancellation and timeouts
* Implement more composition operations on Futures

## License

MiniFuture is released under the MIT license. See `LICENSE.txt` for
details.
