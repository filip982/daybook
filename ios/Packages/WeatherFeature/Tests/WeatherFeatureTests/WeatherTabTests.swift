import DaybookPlatform
import SwiftUI
import Testing
import WeatherFeature

@Suite @MainActor struct WeatherTabTests {
    @Test func publicEntryAcceptsAnyLocationProvider() {
        let tab = WeatherTab(location: StubLocation())
        _ = tab.body
    }
}

private struct StubLocation: LocationProviding {
    func authorization() async -> LocationAuthorization { .notDetermined }
    func current() async throws(LocationError) -> LocatedPlace { throw .unavailable }
}
