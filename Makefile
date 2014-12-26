DSTROOT ?= .
INSTALL_PATH ?= /build

.PHONY: clean test example

test:
	xcodebuild -scheme Test -target Test test

clean:
	rm -fr build DerivedData

example:
	xcodebuild -scheme Example -target Example install DSTROOT=$(DSTROOT)  INSTALL_PATH=$(INSTALL_PATH)
	./build/Example

benchmark:
	xcodebuild -scheme Benchmark -target Benchmark install DSTROOT=$(DSTROOT) INSTALL_PATH=$(INSTALL_PATH)
	./build/Benchmark
