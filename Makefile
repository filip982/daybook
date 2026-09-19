DESTINATION ?= platform=iOS Simulator,name=iPhone 17,OS=26.5
PACKAGES := ios/Packages

.PHONY: ios-test
ios-test:
	cd $(PACKAGES)/DaybookPlatform && xcodebuild test -scheme DaybookPlatform -destination '$(DESTINATION)' -quiet
	cd $(PACKAGES)/WeatherFeature && xcodebuild test -scheme WeatherFeature -destination '$(DESTINATION)' -quiet
