import CoreFoundation

let NumberOfIterations = 10
let NumberOfFlatMapChains = 20_000

func stressTestFutures() {
  var fut = Future.succeeded(0)

  for i in 0..<NumberOfFlatMapChains {
    let futBegin = Future.async { Success(i) }
    let futEnd: Future<Int> = futBegin.flatMap { e0 in
      let futIn0: Future<Int> = Future.succeeded(i).flatMap { e1 in
        // resort to tmp var to help XCode 6.1's indexing job
        let tmp = Future.async { Success(i) }.flatMap { e2 in
          Future.succeeded(e1 + e2)
        }
        return tmp
      }

      let futIn1: Future<Int> = Future.async { Success(i) }.flatMap { e1 in
        // resort to tmp var to help XCode 6.1's indexing job
        let tmp = Future.succeeded(i).flatMap { e2 in
          Future.async { Success(e1 + e2) }
        }
        return tmp
      }

      return futIn0.flatMap { e1 in
        return futIn1.flatMap { e2 in
          Future.succeeded(e0 + e1 + e2)
        }
      }
    }

    fut = fut.flatMap { _ in futEnd }
  }

  fut.get()
}

func avg(samples: [Double]) -> Double {
  let sum = samples.reduce(0.0) { $0 + $1 }
  return sum / Double(samples.count)
}

func variance(samples: [Double], avg: Double) -> Double {
  let total = samples.reduce(0.0) { acc, s in acc + pow(s - avg, 2.0) }
  return total / Double(samples.count)
}

func stddev(samples: [Double], avg: Double) -> Double {
  return sqrt(variance(samples, avg))
}

func measure(label: String, block: () -> Void) {
  var samples: [Double] = []

  for i in 0..<NumberOfIterations {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let end = CFAbsoluteTimeGetCurrent()
    samples.append(end - start)
  }

  let sampleAvg = avg(samples)
  let sampleStdDev = stddev(samples, sampleAvg)

  println(String(format: "%@: %.2f s (± %.2f s)", label, sampleAvg, sampleStdDev))
}

measure("warm up", stressTestFutures)
measure("measure", stressTestFutures)
