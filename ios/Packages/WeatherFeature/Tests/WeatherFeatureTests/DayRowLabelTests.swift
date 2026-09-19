import Foundation
import Testing
@testable import WeatherFeature

@Suite struct DayRowLabelTests {
    static let formatter = WeatherFormatter(
        locale: Locale(identifier: "en_AT"),
        timeZone: TimeZone(identifier: "Europe/Vienna")!
    )

    @Test func theRowExposesTheSpokenDaySentence() {
        let day = Forecast.fixtureVienna.daily[1]
        #expect(
            dayRowLabel(day, formatter: Self.formatter, now: Forecast.fixtureNow)
                == Self.formatter.spokenDay(day, now: Forecast.fixtureNow)
        )
    }

    @Test func todayIsSpokenAsToday() {
        let label = dayRowLabel(
            Forecast.fixtureVienna.daily[0],
            formatter: Self.formatter,
            now: Forecast.fixtureNow
        )
        #expect(label.hasPrefix("Today."))
    }

    @Test func aLikelyDayMentionsItsChance() {
        let label = dayRowLabel(
            Forecast.fixtureVienna.daily[1],
            formatter: Self.formatter,
            now: Forecast.fixtureNow
        )
        #expect(label.contains("70 percent chance"))
    }

    @Test func theHourCellReadsLabelConditionAndTemperature() {
        let hour = Forecast.fixtureVienna.hourly[0]
        #expect(
            hourCellLabel(hour, formatter: Self.formatter, now: Forecast.fixtureNow)
                == "Now, partly cloudy, 18 degrees Celsius"
        )
    }
}
