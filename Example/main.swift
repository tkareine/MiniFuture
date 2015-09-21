import Foundation

enum Error: ErrorType {
  case Deliberate(String)
  case FailedLoadingURL(NSURL)
  case InvalidHTML(String)
}

extension String {
  func excerpt(maxLength: Int) -> String {
    precondition(maxLength >= 0, "maxLength must be positive")

    if maxLength == 0 {
      return ""
    }

    let length = characters.count

    if length <= maxLength {
      return self
    }

    return self[self.startIndex..<startIndex.advancedBy(maxLength-1)] + "…"
  }
}

func immediateFuturesExample() {
  let succeeded = Future.succeeded(1)

  assert(succeeded.isCompleted)
  assert(succeeded.get() == .Success(1))

  let failed = Future<Int>.failed(Error.Deliberate("42"))

  assert(failed.isCompleted)
  assert(failed.get() == .Failure(Error.Deliberate("42")))
}

func asyncFuturesExample() {
  let succeeding = Future<Int>.async {
    NSThread.sleepForTimeInterval(0.2)
    return .Success(1)
  }
  assert(succeeding.get() == .Success(1))

  let failing = Future<Int>.async {
    NSThread.sleepForTimeInterval(0.2)
    return .Failure(Error.Deliberate("42"))
  }
  assert(failing.get() == .Failure(Error.Deliberate("42")))
}

func promiseFuturesExample() {
  let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
  let fut = Future<Int>.promise()

  dispatch_async(queue) {
    NSThread.sleepForTimeInterval(0.2)
    fut.resolve(1)
  }

  assert(fut.isCompleted == false)

  let result = fut.get()
  assert(fut.isCompleted == true)
  assert(result == .Success(1))
}

func chainingFuturesExample() {
  let fut: Future<[Int]> = Future.async { .Success(0) }
    .flatMap { Future.succeeded([$0, 1]) }
    .flatMap { throw Error.Deliberate(String($0)) }
    .flatMap { Future.succeeded($0 + [2]) }

  assert(String(fut.get()) == "Failure(Deliberate(\"[0, 1]\"))")
}

func outerChainingFuturesExample() {
  let fut0: Future<Int> = Future.async { .Success(0) }
  let fut1: Future<[Int]> = fut0.flatMap { Future.succeeded([$0, 1]) }
  let fut2: Future<[Int]> = fut1.flatMap { e in Future.failed(Error.Deliberate(String(e + [2]))) }
  let fut3: Future<[Int]> = fut2.flatMap { Future.succeeded($0 + [3]) }

  assert(String(fut0.get()) == "Success(0)")
  assert(String(fut1.get()) == "Success([0, 1])")
  assert(String(fut2.get()) == "Failure(Deliberate(\"[0, 1, 2]\"))")
  assert(String(fut3.get()) == "Failure(Deliberate(\"[0, 1, 2]\"))")
}

func innerChainingFuturesExample() {
  let fut: Future<[Int]> = Future.succeeded([0]).flatMap { e in
    Future.succeeded(e + [1]).flatMap { e in
      let f: Future<[Int]> = Future.async { Try<[Int]>.Failure(Error.Deliberate(String(e + [2]))) }
      return f.flatMap { Future.succeeded($0 + [3]) }
    }
  }

  do {
    try fut.get().value()
    fatalError("should not come here")
  } catch Error.Deliberate(let err) {
    assert(err == "[0, 1, 2]")
  } catch {
    fatalError("should not come here")
  }
}

func innerAndOuterChainingAsyncFuturesExample() {
  let futBegin = Future.async { .Success(0) }
  let futEnd: Future<[Int]> = futBegin.flatMap { e0 in
    let futIn0 = Future.succeeded(10).flatMap { e1 in
      Future.async { .Success([e1] + [11]) }
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

  assert(futBegin.get() == .Success(0))
  assert(String(futEnd.get()) == "Success([0, 10, 11, 20, 21])")
}

func realisticFutureExample() {
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
}

immediateFuturesExample()
asyncFuturesExample()
promiseFuturesExample()
chainingFuturesExample()
outerChainingFuturesExample()
innerChainingFuturesExample()
innerAndOuterChainingAsyncFuturesExample()
realisticFutureExample()
