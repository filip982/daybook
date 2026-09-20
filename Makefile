DESTINATION ?= platform=iOS Simulator,name=iPhone 17,OS=26.5
PACKAGES := ios/Packages

.DEFAULT_GOAL := all

.PHONY: all
all: lint scripts-test ios-test ios-verify-bundle

.PHONY: ios-test
ios-test:
	cd $(PACKAGES)/DaybookPlatform && xcodebuild test -scheme DaybookPlatform -destination '$(DESTINATION)' -quiet
	cd $(PACKAGES)/WeatherFeature && xcodebuild test -scheme WeatherFeature -destination '$(DESTINATION)' -quiet

.PHONY: ios-snapshots-record
ios-snapshots-record:
	cd $(PACKAGES)/WeatherFeature && TEST_RUNNER_SNAPSHOT_RECORD=1 xcodebuild test -scheme WeatherFeature -destination '$(DESTINATION)' -quiet

.PHONY: ios-test-live
ios-test-live:
	cd $(PACKAGES)/WeatherFeature && TEST_RUNNER_LIVE_TESTS=1 xcodebuild test -scheme WeatherFeature -destination '$(DESTINATION)' -only-testing:WeatherFeatureTests/OpenMeteoLiveTests -quiet

DERIVED := ios/build/DerivedData

.PHONY: project ios-build ios-verify-bundle
project:
	cd ios && xcodegen generate --quiet

ios-build: project
	xcodebuild build -project ios/Daybook.xcodeproj -scheme Daybook -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -quiet CODE_SIGNING_ALLOWED=NO

ios-verify-bundle: ios-build
	scripts/verify-bundle.sh $(DERIVED)/Build/Products/Debug-iphonesimulator/Daybook.app

ARCHIVE := ios/build/Daybook.xcarchive
VERSION ?= 0.0.0
BUILD ?= 1

.PHONY: ios-archive ios-verify-archive ios-upload
ios-archive: project
	xcodebuild archive -project ios/Daybook.xcodeproj -scheme Daybook -configuration Release -destination 'generic/platform=iOS' -archivePath $(ARCHIVE) -derivedDataPath $(DERIVED) -quiet MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(BUILD) CODE_SIGNING_ALLOWED=NO

ios-verify-archive:
	EXPECT_VERSION=$(VERSION) EXPECT_BUILD=$(BUILD) scripts/verify-bundle.sh $(ARCHIVE)/Products/Applications/Daybook.app

ios-upload:
	@test -n "$(ASC_KEY_PATH)" -a -n "$(ASC_KEY_ID)" -a -n "$(ASC_ISSUER_ID)" || { echo "ios-upload: ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID are required" >&2; exit 1; }
	@xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportOptionsPlist ios/ExportOptions.plist -exportPath ios/build/export -allowProvisioningUpdates -authenticationKeyPath "$(ASC_KEY_PATH)" -authenticationKeyID "$(ASC_KEY_ID)" -authenticationKeyIssuerID "$(ASC_ISSUER_ID)"

.PHONY: lint
lint:
	scripts/test-lint-layers.sh
	scripts/lint-layers.sh

.PHONY: scripts-test
scripts-test:
	scripts/test-release-info.sh
