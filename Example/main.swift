import Foundation

enum AppError: Error {
  case deliberate(String)
  case failedLoadingURL(URL)
  case invalidHTML(String)
}

extension String {
  var trimmed: String {
    return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
  }

  func excerpt(_ maxLength: Int) -> String {
    precondition(maxLength >= 0, "maxLength must be positive")

    if maxLength == 0 {
      return ""
    }

    let length = count

    if length <= maxLength {
      return self
    }

    return String(self[startIndex..<index(startIndex, offsetBy: maxLength-1)]).trimmed + "…"
  }
}

func immediateFuturesExample() {
  let succeeded = Future.succeeded(1)

  assert(succeeded.isCompleted)
  assert(succeeded.get() == .success(1))

  let failed = Future<Int>.failed(AppError.deliberate("42"))

  assert(failed.isCompleted)
  assert(failed.get() == .failure(AppError.deliberate("42")))
}

func asyncFuturesExample() {
  let succeeding = Future<Int>.async {
    Thread.sleep(forTimeInterval: 0.2)
    return .success(1)
  }
  assert(succeeding.get() == .success(1))

  let failing = Future<Int>.async {
    Thread.sleep(forTimeInterval: 0.2)
    return .failure(AppError.deliberate("42"))
  }
  assert(failing.get() == .failure(AppError.deliberate("42")))
}

func promiseFuturesExample() {
  let queue = DispatchQueue.global()
  let fut = Future<Int>.promise()

  queue.async {
    Thread.sleep(forTimeInterval: 0.2)
    fut.resolve(1)
  }

  assert(fut.isCompleted == false)

  let result = fut.get()
  assert(fut.isCompleted == true)
  assert(result == .success(1))
}

func chainingFuturesExample() {
  let fut: Future<[Int]> = Future.async { .success(0) }
    .flatMap { Future.succeeded([$0, 1]) }
    .flatMap { throw AppError.deliberate(String(describing: $0)) }
    .flatMap { Future.succeeded($0 + [2]) }

  assert(String(describing: fut.get()) == "Try.failure(deliberate(\"[0, 1]\"))")
}

func outerChainingFuturesExample() {
  let fut0: Future<Int> = Future.async { .success(0) }
  let fut1: Future<[Int]> = fut0.flatMap { Future.succeeded([$0, 1]) }
  let fut2: Future<[Int]> = fut1.flatMap { e in Future.failed(AppError.deliberate(String(describing: e + [2]))) }
  let fut3: Future<[Int]> = fut2.flatMap { Future.succeeded($0 + [3]) }

  assert(String(describing: fut0.get()) == "Try.success(0)")
  assert(String(describing: fut1.get()) == "Try.success([0, 1])")
  assert(String(describing: fut2.get()) == "Try.failure(deliberate(\"[0, 1, 2]\"))")
  assert(String(describing: fut3.get()) == "Try.failure(deliberate(\"[0, 1, 2]\"))")
}

func innerChainingFuturesExample() {
  let fut: Future<[Int]> = Future.succeeded([0]).flatMap { e in
    Future.succeeded(e + [1]).flatMap { e in
      let f: Future<[Int]> = Future.async { Try<[Int]>.failure(AppError.deliberate(String(describing: e + [2]))) }
      return f.flatMap { Future.succeeded($0 + [3]) }
    }
  }

  do {
    let _ = try fut.get().value()
    fatalError("should not come here")
  } catch AppError.deliberate(let err) {
    assert(err == "[0, 1, 2]")
  } catch {
    fatalError("should not come here")
  }
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

  assert(futBegin.get() == .success(0))
  assert(String(describing: futEnd.get()) == "Try.success([0, 10, 11, 20, 21])")
}

func realisticFutureExample() {
  /**
   * Request a web resource asynchronously, immediately returning a handle to
   * the job as a promise kind of Future. When NSURLSession calls the completion
   * handler, we fullfill the promise. If the completion handler gets called
   * with the contents of the web resource, we resolve the promise with the
   * contents (the success case). Otherwise, we reject the promise with failure.
   */
  func loadURL(_ url: URL) -> Future<Data> {
    let promise = Future<Data>.promise()
    let task = URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
      if let err = error {
        promise.reject(err)
      } else if let d = data {
        promise.resolve(d)
      } else {
        promise.reject(AppError.failedLoadingURL(url))
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
  func readXPathFromHTML(_ xpath: String, data: Data) throws -> Future<HTMLNode> {
    let doc = try HTMLDocument.readData(asUTF8: data)
    let node = try doc.rootHTMLNode()
    let found = try node.forXPath(xpath)
    return Future.succeeded(found)
  }

  let wikipediaURL = URL(string: "https://en.wikipedia.org/wiki/Main_Page")!
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
  case .success(let value):
    let excerpt = value.textContents!.excerpt(78)
    print("Excerpt from today's featured article at Wikipedia: \(excerpt)")
  case .failure(let error):
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
