.DEFAULT_GOAL := help
.PHONY: help xcode build test e2e lint lint\:all fmt fmt\:all app desk release check clean

BASE ?= origin/main
SWIFT_PATHS := Package.swift Sources Tests csum csumTests csumUITests
DERIVED := .build/xcode
PRODUCTS := $(DERIVED)/Build/Products
CATALYST := generic/platform=macOS,variant=Mac Catalyst
RELEASE_APP := $(PRODUCTS)/Release-maccatalyst/csum.app
DESKTOP_DIR ?= $(HOME)/Desktop
DESK_APP := $(DESKTOP_DIR)/csum.app

help:            ## List available commands
	@grep -E '^[a-z][a-z\\:-]*:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":[^:]*## "}; {gsub(/\\/, "", $$1); printf "  %-9s %s\n", $$1, $$2}'

xcode:           ## Open the app project
	open csum.xcodeproj

build:           ## Build the package (CLI and controller)
	swift build

test: build      ## Run the controller tests
	swift test

e2e: build       ## Run the CLI against shasum
	bash Tests/e2e.sh

lint:            ## Check formatting of changed Swift files
	@base="$$(git merge-base "$(BASE)" HEAD)"; \
	files="$$(git diff --name-only --diff-filter=d "$$base" -- '*.swift')"; \
	if [ -z "$$files" ]; then \
		echo "no changed Swift files"; \
	else \
		echo "$$files" | xargs swift format lint --strict --parallel --configuration .swift-format; \
	fi

lint\:all:       ## Check formatting of every Swift file
	swift format lint --recursive --strict --parallel --configuration .swift-format $(SWIFT_PATHS)

fmt:             ## Format changed Swift files in place
	@base="$$(git merge-base "$(BASE)" HEAD)"; \
	files="$$(git diff --name-only --diff-filter=d "$$base" -- '*.swift')"; \
	if [ -z "$$files" ]; then \
		echo "no changed Swift files"; \
	else \
		echo "$$files" | xargs swift format --in-place --configuration .swift-format; \
	fi

fmt\:all:        ## Format every Swift file in place
	swift format --in-place --recursive --configuration .swift-format $(SWIFT_PATHS)

app:             ## Build the Mac Catalyst app (debug)
	xcodebuild -quiet -project csum.xcodeproj -scheme csum -configuration Debug \
		-destination '$(CATALYST)' -derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO build

desk:            ## Build the Mac Catalyst app (release) and copy it to the Desktop
	xcodebuild -quiet -project csum.xcodeproj -scheme csum -configuration Release \
		-destination '$(CATALYST)' -derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO build
	rm -rf '$(DESK_APP)'
	ditto '$(RELEASE_APP)' '$(DESK_APP)'

release:         ## Build the universal release CLI
	swift build -c release --arch arm64 --arch x86_64

check: test e2e lint  ## Run tests, e2e, and lint

clean:           ## Remove build products
	rm -rf .build
