#if DEBUG
import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

@Suite struct FixtureProviderTests {
    @Test func arbitraryCoordinateReturnsTheViennaFixture() async throws {
        let provider = FixtureProvider()

        let forecast = try await provider.forecast(for: Coordinate(latitude: 1, longitude: 1))

        #expect(forecast == .fixtureVienna)
    }

    @Test func torontosRoundedCoordinateReturnsTheTorontoFixture() async throws {
        let provider = FixtureProvider()
        let toronto = SavedLocation.fixtures.first { $0.name == "Toronto" }!

        let forecast = try await provider.forecast(for: toronto.coordinate)

        #expect(forecast == .fixtureToronto)
    }

    @Test func searchWithACasInsensitivePrefixReturnsOnlyTheMatchingLocation() async throws {
        let provider = FixtureProvider()

        let results = try await provider.search("os")

        #expect(results == [SavedLocation.fixtures.first { $0.name == "Oslo" }!])
    }

    @Test func searchWithAnEmptyQueryReturnsNoResults() async throws {
        let provider = FixtureProvider()

        let results = try await provider.search("")

        #expect(results == [])
    }

    @Test func searchTrimsTheQueryBeforeMatching() async throws {
        let provider = FixtureProvider()

        let results = try await provider.search("  os  ")

        #expect(results == [SavedLocation.fixtures.first { $0.name == "Oslo" }!])
    }
}
#endif
