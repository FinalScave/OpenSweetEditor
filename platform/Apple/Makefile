SHELL := /bin/bash

.PHONY: help all native native-if-needed xcode-prebuild build test verify-local demo-macos-build demo-macos-run demo-macos-run-swiftui clean

help:
	@echo "make all              # native-if-needed + swift build + swift test"
	@echo "make native           # force rebuild SweetNativeCore.xcframework"
	@echo "make native-if-needed # rebuild only when sources are newer"
	@echo "make xcode-prebuild   # alias for native-if-needed"
	@echo "make build            # swift build"
	@echo "make test             # swift test"
	@echo "make verify-local     # package describe + swift build"
	@echo "make demo-macos-build # build macOS demo app"
	@echo "make demo-macos-run   # run macOS AppKit demo app"
	@echo "make demo-macos-run-swiftui # run macOS SwiftUI demo app"
	@echo "make clean            # remove swift and native build outputs"

all: native-if-needed build test

native:
	./scripts/build_native_xcframework.sh

native-if-needed:
	./scripts/xcode_prebuild.sh

xcode-prebuild: native-if-needed

build:
	swift build

test:
	swift test

verify-local:
	./scripts/verify_local.sh

DEMO_MODULE_CACHE := $(CURDIR)/Examples-MacOS/.build/module-cache
DEMO_BUILD_ENV := SWIFT_MODULECACHE_PATH=$(DEMO_MODULE_CACHE) CLANG_MODULE_CACHE_PATH=$(DEMO_MODULE_CACHE)
DEMO_SWIFT_FLAGS := --disable-sandbox

demo-macos-build:
	mkdir -p $(DEMO_MODULE_CACHE)
	cd Examples-MacOS && $(DEMO_BUILD_ENV) swift build $(DEMO_SWIFT_FLAGS)

demo-macos-run:
	mkdir -p $(DEMO_MODULE_CACHE)
	cd Examples-MacOS && $(DEMO_BUILD_ENV) swift run $(DEMO_SWIFT_FLAGS) SweetEditorMacDemo

demo-macos-run-swiftui:
	mkdir -p $(DEMO_MODULE_CACHE)
	cd Examples-MacOS && $(DEMO_BUILD_ENV) swift run $(DEMO_SWIFT_FLAGS) SweetEditorMacDemoSwiftUI

clean:
	rm -rf .build
	rm -rf ../../build/apple-macos
	rm -rf binaries/SweetNativeCore.xcframework
