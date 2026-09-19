#if DEBUG
import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

private struct StubProvider: WeatherProvider {
    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        guard coordinate.latitude != 0 else { throw .notFound }
        return .fixtureVienna
    }

    func search(_ query: String) async throws(WeatherError) -> [SavedLocation] {
        query.isEmpty ? [] : SavedLocation.fixtures
    }
}

@Suite struct WeatherProviderTests {
    @Test func conformanceReturnsForecastAndSearchResults() async throws {
        let provider: any WeatherProvider = StubProvider()

        let forecast = try await provider.forecast(for: Coordinate(latitude: 48.21, longitude: 16.37))
        let matches = try await provider.search("Lisbon")
        let empty = try await provider.search("")

        #expect(forecast.timeZone.identifier == "Europe/Vienna")
        #expect(matches.isEmpty == false)
        #expect(empty.isEmpty)
    }

    @Test func typedThrowsPropagatesWeatherError() async {
        let provider: any WeatherProvider = StubProvider()
        let origin = Coordinate(latitude: 0, longitude: 0)

        await #expect(throws: WeatherError.notFound) {
            try await provider.forecast(for: origin)
        }
    }
}
#endif
