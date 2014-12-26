DSTROOT ?= .
INSTALL_PATH ?= /build

.PHONY: test test-all clean example benchmark

test:
	xcodebuild -scheme Test -target Test test

test-all: test example

clean:
	rm -fr build DerivedData

example:
	xcodebuild -scheme Example -target Example install DSTROOT=$(DSTROOT)  INSTALL_PATH=$(INSTALL_PATH)
	./build/Example

benchmark:
	xcodebuild -scheme Benchmark -target Benchmark install DSTROOT=$(DSTROOT) INSTALL_PATH=$(INSTALL_PATH)
	./build/Benchmark
