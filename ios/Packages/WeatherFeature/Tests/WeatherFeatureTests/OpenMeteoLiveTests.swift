import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

extension Tag {
    @Tag static var live: Self
}

@Suite(.tags(.live), .enabled(if: ProcessInfo.processInfo.environment["LIVE_TESTS"] == "1"))
struct OpenMeteoLiveTests {
    private let vienna = Coordinate(latitude: 48.21, longitude: 16.37)

    @Test func forecastMatchesTheCurrentSchema() async throws {
        let subject = OpenMeteoProvider()

        let forecast = try await subject.forecast(for: vienna)

        #expect(TimeZone(identifier: forecast.timeZone.identifier) != nil)
        #expect(forecast.hourly.count == 24)
        #expect(forecast.daily.count == 10)
    }

    @Test func searchMatchesTheCurrentSchema() async throws {
        let subject = OpenMeteoProvider()

        let results = try await subject.search("Lisbon")

        let first = try #require(results.first)
        #expect(TimeZone(identifier: first.timeZoneIdentifier) != nil)
    }
}
