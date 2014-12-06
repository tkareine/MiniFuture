import CoreFoundation

let NumberOfIterations = 100
let NumberOfFutureCompositions = 2000

func stressTestFutures() {
  var fut = Future.succeeded(0)

  for i in 0..<NumberOfFutureCompositions {
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

struct Measurement {
  let mean: Double
  let stddev: Double

  init(from samples: [Double]) {
    mean = Measurement.mean(samples)
    stddev = Measurement.stddev(samples, mean)
  }

  static func mean(samples: [Double]) -> Double {
    let sum = samples.reduce(0.0) { $0 + $1 }
    return sum / Double(samples.count)
  }

  static func variance(samples: [Double], _ mean: Double) -> Double {
    let total = samples.reduce(0.0) { acc, s in acc + pow(s - mean, 2.0) }
    return total / Double(samples.count)
  }

  static func stddev(samples: [Double], _ mean: Double) -> Double {
    return sqrt(variance(samples, mean))
  }
}

func measure(block: () -> Void) -> Measurement {
  var samples: [Double] = []

  for _ in 0..<NumberOfIterations {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let end = CFAbsoluteTimeGetCurrent()
    samples.append((end - start) * 1000)
  }

  return Measurement(from: samples)
}

func formatMeasurement(label: String, withData m: Measurement) -> String {
  return String(format: "%@: %.f ms (± %.f ms)", label, m.mean, m.stddev)
}

println("iterations: \(NumberOfIterations), futures composed: \(NumberOfFutureCompositions)\n")

println(formatMeasurement("warm up", withData: measure(stressTestFutures)))
println(formatMeasurement("measure", withData: measure(stressTestFutures)))
