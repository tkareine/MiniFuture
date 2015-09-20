import Foundation

func assertToString<T>(actual: T, _ expected: String) {
  assert(String(actual) == expected)
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
  assertToString(succeeded.get(), "Success(1)")

  let failed = Future<Int>.failed("deliberate")

  assert(failed.isCompleted)
  assertToString(failed.get(), "Failure(\"deliberate\")")
}

func asyncFuturesExample() {
  let succeeding = Future<Int>.async {
    NSThread.sleepForTimeInterval(0.2)
    return .success(1)
  }
  assertToString(succeeding.get(), "Success(1)")

  let failing = Future<Int>.async {
    NSThread.sleepForTimeInterval(0.2)
    return .failure("deliberate")
  }
  assertToString(failing.get(), "Failure(\"deliberate\")")
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
  assertToString(result, "Success(1)")
}

func outerChainingFuturesExample() {
  let fut0: Future<Int> = Future.async { .success(0) }
  let fut1: Future<[Int]> = fut0.flatMap { Future.succeeded([$0, 1]) }
  let fut2: Future<[Int]> = fut1.flatMap { e in Future.failed(String(e + [2])) }
  let fut3: Future<[Int]> = fut2.flatMap { Future.succeeded($0 + [3]) }

  assertToString(fut0.get(), "Success(0)")
  assertToString(fut1.get(), "Success([0, 1])")
  assertToString(fut2.get(), "Failure(\"[0, 1, 2]\")")
  assertToString(fut3.get(), "Failure(\"[0, 1, 2]\")")
}

func innerChainingFuturesExample() {
  let fut: Future<[Int]> = Future.succeeded([0]).flatMap { e in
    Future.succeeded(e + [1]).flatMap { e in
      let f: Future<[Int]> = Future.async { .failure(String(e + [2])) }
      return f.flatMap { Future.succeeded($0 + [3]) }
    }
  }

  assertToString(fut.get(), "Failure(\"[0, 1, 2]\")")
}

func innerAndOuterChainingAsyncFuturesExample() {
  let futBegin = Future.async { .success(0) }
  let futEnd: Future<[Int]> = futBegin.flatMap { e0 in
    let futIn0 = Future.succeeded(10).flatMap { e1 in
      Future.async { .success([e1] + [11]) }
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

  assertToString(futBegin.get(), "Success(0)")
  assertToString(futEnd.get(), "Success([0, 10, 11, 20, 21])")
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
    let doc: HTMLDocument
    let node: HTMLNode
    let found: HTMLNode

    do {
      doc = try HTMLDocument.readDataAsUTF8(data)
      node = try doc.rootHTMLNode()
      found = try node.nodeForXPath(xpath)
    } catch let error as NSError {
      return Future.failed("failed parsing HTML: \(error)")
    }

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
    .flatMap { readXPathFromHTML(featuredArticleXPath, data: $0) }
    /* Wait for Future chain to complete. This acts as a synchronization point.
     */
    .get()

  switch result {
  case .Success(let value):
    let excerpt = value.textContents!.excerpt(72)
    print("Excerpt from today's featured article at Wikipedia: \(excerpt)")
  case .Failure(let desc):
    print("Error getting today's featured article from Wikipedia: \(desc)")
  }
}

immediateFuturesExample()
asyncFuturesExample()
promiseFuturesExample()
outerChainingFuturesExample()
innerChainingFuturesExample()
innerAndOuterChainingAsyncFuturesExample()
realisticFutureExample()
