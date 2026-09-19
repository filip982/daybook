DESTINATION ?= platform=iOS Simulator,name=iPhone 17,OS=26.5
PACKAGES := ios/Packages

.PHONY: ios-test
ios-test:
	cd $(PACKAGES)/DaybookPlatform && xcodebuild test -scheme DaybookPlatform -destination '$(DESTINATION)' -quiet
	cd $(PACKAGES)/WeatherFeature && xcodebuild test -scheme WeatherFeature -destination '$(DESTINATION)' -quiet

DERIVED := ios/build/DerivedData

.PHONY: project ios-build ios-verify-bundle
project:
	cd ios && xcodegen generate --quiet

ios-build: project
	xcodebuild build -project ios/Daybook.xcodeproj -scheme Daybook -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -quiet CODE_SIGNING_ALLOWED=NO

ios-verify-bundle:
	scripts/verify-bundle.sh

.PHONY: lint
lint:
	scripts/test-lint-layers.sh
	scripts/lint-layers.sh
