import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

@Suite struct LiveWeatherStoreLiveLanguageCodeTests {
    @Test func enUSResolvesToEn() {
        #expect(LiveWeatherStore.languageCode(for: Locale(identifier: "en_US")) == "en")
    }

    @Test func deATResolvesToDe() {
        #expect(LiveWeatherStore.languageCode(for: Locale(identifier: "de_AT")) == "de")
    }

    @Test func aLocaleWithNoLanguageFallsBackToEn() {
        #expect(LiveWeatherStore.languageCode(for: Locale(identifier: "")) == "en")
    }
}

@Suite struct LiveWeatherStoreLiveFactoryTests {
    #if DEBUG
    @Test func fixtureLaunchArgumentYieldsAStoreServingTheFixtureForecastWithNoNetwork() async throws {
        let cacheDirectory = try TemporaryDirectory()
        let savedLocationsDirectory = try TemporaryDirectory()
        let fixedNow = Forecast.fixtureNow
        let store = LiveWeatherStore.live(
            arguments: ["app", LiveWeatherStore.fixtureLaunchArgument],
            cacheDirectory: cacheDirectory.url,
            savedLocationsURL: savedLocationsDirectory.url.appendingPathComponent("saved-locations.json"),
            now: { fixedNow }
        )

        let forecast = try await store.refreshForecast(for: Coordinate(latitude: 1, longitude: 1))

        #expect(forecast == .fixtureVienna)
    }
    #endif

    @Test func withoutTheFixtureArgumentTheStoreStartsWithAnEmptyCacheInAFreshDirectory() async throws {
        let cacheDirectory = try TemporaryDirectory()
        let savedLocationsDirectory = try TemporaryDirectory()
        let store = LiveWeatherStore.live(
            arguments: ["app"],
            cacheDirectory: cacheDirectory.url,
            savedLocationsURL: savedLocationsDirectory.url.appendingPathComponent("saved-locations.json"),
            now: { Date() }
        )

        let cached = await store.cachedForecast(for: Coordinate(latitude: 48.21, longitude: 16.37))

        #expect(cached == nil)
    }
}
