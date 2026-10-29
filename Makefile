SCHEME ?= SnapKcal
SIMULATOR ?= iPhone 17 Pro
DERIVED_DATA ?= build
DEVICE ?=
APP_PATH = $(DERIVED_DATA)/Build/Products/Release-iphoneos/SnapKcal.app

.PHONY: help setup generate build test ui-test device install clean

help:
	@echo "make setup     Create .env and signing config, generate the Xcode project"
	@echo "make generate  Regenerate SnapKcal.xcodeproj from project.yml"
	@echo "make build     Build for the iOS Simulator ($(SIMULATOR))"
	@echo "make test      Run unit tests on the iOS Simulator"
	@echo "make ui-test   Run UI tests on the iOS Simulator"
	@echo "make device    Build a signed Release app for a connected iPhone"
	@echo "make install   Install the Release app on DEVICE=<devicectl id>"
	@echo "make clean     Remove build output"

setup:
	@command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
	@[ -f .env ] || { cp .env.example .env; echo "Created .env"; }
	@[ -f Config/Signing.local.xcconfig ] || { cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig; echo "Created Config/Signing.local.xcconfig, set DEVELOPMENT_TEAM and BUNDLE_ID_PREFIX"; }
	@$(MAKE) generate

generate:
	xcodegen generate

build: generate
	xcodebuild build -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=$(SIMULATOR)' -derivedDataPath $(DERIVED_DATA)

test: generate
	xcodebuild test -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=$(SIMULATOR)' -derivedDataPath $(DERIVED_DATA) -only-testing:SnapKcalTests

ui-test: generate
	xcodebuild test -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=$(SIMULATOR)' -derivedDataPath $(DERIVED_DATA) -only-testing:SnapKcalUITests

device: generate
	xcodebuild build -scheme $(SCHEME) -destination 'generic/platform=iOS' -configuration Release -derivedDataPath $(DERIVED_DATA) -allowProvisioningUpdates

install:
	@[ -n "$(DEVICE)" ] || { echo "Usage: make install DEVICE=<id from 'xcrun devicectl list devices'>"; exit 1; }
	xcrun devicectl device install app --device $(DEVICE) $(APP_PATH)

clean:
	rm -rf $(DERIVED_DATA)
