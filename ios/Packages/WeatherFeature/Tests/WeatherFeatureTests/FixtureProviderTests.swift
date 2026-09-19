#if DEBUG
import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

@Suite struct FixtureProviderTests {
    private static let now = Forecast.fixtureNow

    @Test func arbitraryCoordinateReturnsTheViennaFixture() async throws {
        let provider = FixtureProvider(now: { Self.now })

        let forecast = try await provider.forecast(for: Coordinate(latitude: 1, longitude: 1))

        #expect(forecast.timeZone.identifier == "Europe/Vienna")
    }

    @Test func torontosRoundedCoordinateReturnsTheTorontoFixture() async throws {
        let provider = FixtureProvider(now: { Self.now })
        let toronto = SavedLocation.fixtures.first { $0.name == "Toronto" }!

        let forecast = try await provider.forecast(for: toronto.coordinate)

        #expect(forecast.timeZone.identifier == "America/Toronto")
    }

    @Test(arguments: [("Lisbon", "Europe/Lisbon"), ("Oslo", "Europe/Oslo"), ("Toronto", "America/Toronto")])
    func eachSavedCityReturnsAForecastInItsOwnZone(name: String, zone: String) async throws {
        let provider = FixtureProvider(now: { Self.now })
        let location = try #require(SavedLocation.fixtures.first { $0.name == name })

        let forecast = try await provider.forecast(for: location.coordinate)

        #expect(forecast.timeZone.identifier == zone)
    }

    @Test func fetchedAtIsTheInjectedNow() async throws {
        let injected = Forecast.fixtureNow.addingTimeInterval(1234)
        let provider = FixtureProvider(now: { injected })

        let forecast = try await provider.forecast(for: Coordinate(latitude: 1, longitude: 1))

        #expect(forecast.fetchedAt == injected)
    }

    @Test func searchWithACasInsensitivePrefixReturnsOnlyTheMatchingLocation() async throws {
        let provider = FixtureProvider(now: { Self.now })

        let results = try await provider.search("os")

        #expect(results == [SavedLocation.fixtures.first { $0.name == "Oslo" }!])
    }

    @Test func searchWithAnEmptyQueryReturnsNoResults() async throws {
        let provider = FixtureProvider(now: { Self.now })

        let results = try await provider.search("")

        #expect(results == [])
    }

    @Test func searchTrimsTheQueryBeforeMatching() async throws {
        let provider = FixtureProvider(now: { Self.now })

        let results = try await provider.search("  os  ")

        #expect(results == [SavedLocation.fixtures.first { $0.name == "Oslo" }!])
    }
}
#endif
