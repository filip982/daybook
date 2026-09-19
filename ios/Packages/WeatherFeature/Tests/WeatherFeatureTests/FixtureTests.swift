#if DEBUG
import Foundation
import Testing
@testable import WeatherFeature

private extension Forecast {
    static func fixture(inZone zone: String) -> Forecast? {
        switch zone {
        case "Europe/Lisbon": .fixtureLisbon
        case "Europe/Oslo": .fixtureOslo
        default: nil
        }
    }
}

@Suite struct FixtureTests {
    @Test func viennaHasTwentyFourHourlyEntriesOneHourApart() {
        let hourly = Forecast.fixtureVienna.hourly
        #expect(hourly.count == 24)

        let steps = zip(hourly, hourly.dropFirst()).map { $1.time.timeIntervalSince($0.time) }
        #expect(steps.allSatisfy { $0 == 3600 })
    }

    @Test func viennaHasTenDailyEntriesOneCalendarDayApart() throws {
        let daily = Forecast.fixtureVienna.daily
        #expect(daily.count == 10)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Vienna"))

        for (previous, next) in zip(daily, daily.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: previous.date, to: next.date).day == 1)
            #expect(calendar.startOfDay(for: previous.date) == previous.date)
        }
        #expect(calendar.startOfDay(for: try #require(daily.last).date) == daily.last?.date)
    }

    @Test func viennaIsFresh() {
        #expect(Forecast.fixtureVienna.isStale(now: Forecast.fixtureNow) == false)
    }

    @Test func viennaSummarisesAsConditionAndHigh() {
        let summary = DaySummary.make(from: .fixtureVienna, now: Forecast.fixtureNow)
        #expect(summary == .conditionAndHigh(code: WeatherCode(wmo: 2), highCelsius: 21))
    }

    @Test func torontoIsStale() {
        #expect(Forecast.fixtureToronto.isStale(now: Forecast.fixtureNow))
    }

    @Test func torontoIsNightInItsOwnZone() {
        #expect(Forecast.fixtureToronto.current.isDay == false)
        #expect(Forecast.fixtureToronto.timeZone.identifier == "America/Toronto")
    }

    @Test(arguments: ["Europe/Lisbon", "Europe/Oslo"])
    func newFixtureHasTwentyFourHourlyEntriesStartingAtTheHourContainingFixtureNow(zone: String) throws {
        let forecast = try #require(Forecast.fixture(inZone: zone))
        let hourly = forecast.hourly
        #expect(hourly.count == 24)

        let steps = zip(hourly, hourly.dropFirst()).map { $1.time.timeIntervalSince($0.time) }
        #expect(steps.allSatisfy { $0 == 3600 })

        let first = try #require(hourly.first).time
        #expect(first <= Forecast.fixtureNow)
        #expect(Forecast.fixtureNow < first.addingTimeInterval(3600))
        #expect(forecast.timeZone.identifier == zone)
    }

    @Test(arguments: ["Europe/Lisbon", "Europe/Oslo"])
    func newFixtureHasTenDailyEntriesAtLocalMidnightOneDayApart(zone: String) throws {
        let forecast = try #require(Forecast.fixture(inZone: zone))
        let daily = forecast.daily
        #expect(daily.count == 10)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))

        #expect(daily.allSatisfy { calendar.startOfDay(for: $0.date) == $0.date })
        for (previous, next) in zip(daily, daily.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: previous.date, to: next.date).day == 1)
        }
        #expect(calendar.startOfDay(for: Forecast.fixtureNow) == daily.first?.date)
    }

    @Test(arguments: ["Europe/Lisbon", "Europe/Oslo"])
    func newFixtureIsFreshAtFixtureNow(zone: String) throws {
        let forecast = try #require(Forecast.fixture(inZone: zone))
        #expect(forecast.isStale(now: Forecast.fixtureNow) == false)
    }

    @Test func osloSummarisesAsARainWindow() throws {
        let summary = try #require(DaySummary.make(from: .fixtureOslo, now: Forecast.fixtureNow))
        if case .precipitation(let kind, _, _) = summary {
            #expect(kind == .rain)
        } else {
            Issue.record("expected a precipitation summary, got \(summary)")
        }
    }

    @Test func lisbonSummarisesWithoutPrecipitation() throws {
        let summary = try #require(DaySummary.make(from: .fixtureLisbon, now: Forecast.fixtureNow))
        switch summary {
        case .conditionAndHigh, .warmingUp:
            break
        default:
            Issue.record("expected condition-and-high or warming-up, got \(summary)")
        }
    }

    @Test func savedLocationFixturesAreThreeDistinctResolvableZones() {
        let fixtures = SavedLocation.fixtures
        #expect(fixtures.count == 3)
        #expect(Set(fixtures.map(\.id)).count == 3)
        #expect(fixtures.allSatisfy { TimeZone(identifier: $0.timeZoneIdentifier) != nil })
    }
}
#endif
