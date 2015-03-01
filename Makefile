DSTROOT ?= .
INSTALL_PATH ?= /build

.PHONY: test-all test-ios test-mac clean example benchmark lint-pod

test-all: test-ios test-mac example lint-pod

test-ios:
	xcodebuild -scheme Test-ios -target Test-ios -destination 'platform=iOS Simulator,name=iPhone 5s,OS=latest' -destination-timeout 10 test

test-mac:
	xcodebuild -scheme Test-mac -target Test-mac -destination 'platform=OS X,arch=x86_64' -destination-timeout 10 test

clean:
	rm -fr build DerivedData

example:
	xcodebuild -scheme Example -target Example install DSTROOT=$(DSTROOT)  INSTALL_PATH=$(INSTALL_PATH)
	./build/Example

benchmark:
	xcodebuild -scheme Benchmark -target Benchmark install DSTROOT=$(DSTROOT) INSTALL_PATH=$(INSTALL_PATH)
	./build/Benchmark

lint-pod:
	pod lib lint --quick
