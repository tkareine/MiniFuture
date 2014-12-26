.PHONY: clean test example

test:
	xcodebuild -scheme Test -target Test clean test

clean:
	rm -fr Build

Build/Example:
	xcodebuild -scheme Example -target Example clean install DSTROOT=. INSTALL_PATH=/Build

Build/Benchmark:
	xcodebuild -scheme Benchmark -target Benchmark clean install DSTROOT=. INSTALL_PATH=/Build

example: clean Build/Example
	./Build/Example

benchmark: clean Build/Benchmark
	./Build/Benchmark
