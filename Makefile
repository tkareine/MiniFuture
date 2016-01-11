DSTROOT ?= .
INSTALL_PATH ?= /build

.PHONY: clean test-all test-ios test-mac example benchmark lint-pod

test-all: test-ios test-mac example lint-pod

test-ios:
	xcodebuild -scheme Test-ios -configuration Debug -target Test-ios -destination 'platform=iOS Simulator,name=iPhone 5s,OS=latest' -destination-timeout 10 test

test-mac:
	xcodebuild -scheme Test-mac -configuration Debug -target Test-mac -destination 'platform=OS X,arch=x86_64' -destination-timeout 10 test

example:
	xcodebuild -scheme Example -configuration Release -target Example install DSTROOT=$(DSTROOT)  INSTALL_PATH=$(INSTALL_PATH)
	./build/Example

benchmark:
	xcodebuild -scheme Benchmark -configuration Release -target Benchmark install DSTROOT=$(DSTROOT) INSTALL_PATH=$(INSTALL_PATH)
	./build/Benchmark
	@echo
	@swiftc --version

lint-pod:
	pod lib lint --quick

clean:
	rm -fr build DerivedData
