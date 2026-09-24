import Foundation
import Testing
@testable import WeatherFeature

@Suite struct WeatherFormatterTests {
    static let vienna = TimeZone(identifier: "Europe/Vienna")!
    static let toronto = TimeZone(identifier: "America/Toronto")!
    static let metric = Locale(identifier: "en_AT")
    static let imperial = Locale(identifier: "en_US")

    static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, in zone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    static let metricFormatter = WeatherFormatter(locale: metric, timeZone: vienna)
    static let imperialFormatter = WeatherFormatter(locale: imperial, timeZone: vienna)

    @Test func metricTemperatureRoundsToWholeDegrees() {
        #expect(Self.metricFormatter.temperature(18.4) == "18°")
    }

    @Test func slightlyBelowZeroNeverRendersNegativeZero() {
        #expect(Self.metricFormatter.temperature(-0.4) == "0°")
    }

    @Test func belowHalfADegreeBelowZeroStillRendersNegativeOne() {
        #expect(Self.metricFormatter.temperature(-1.4) == "-1°")
    }

    @Test func imperialTemperatureConvertsToFahrenheit() {
        #expect(Self.imperialFormatter.temperature(18) == "64°")
    }

    @Test func imperialGustsConvertToMilesPerHour() {
        #expect(Self.imperialFormatter.gusts(60).contains("mph"))
    }

    @Test func metricGustsStayInKilometresPerHour() {
        #expect(Self.metricFormatter.gusts(60) == "60 km/h")
    }

    @Test func spokenTemperatureNamesTheScale() {
        #expect(Self.metricFormatter.spokenTemperature(18) == "18 degrees Celsius")
    }

    @Test func spokenTemperatureSpeaksTheUnitTheLabelShows() {
        #expect(Self.imperialFormatter.spokenTemperature(18) == "64 degrees Fahrenheit")
    }

    @Test func anExplicitCelsiusOverrideBeatsTheRegion() {
        let formatter = WeatherFormatter(locale: Locale(identifier: "en-US-u-mu-celsius"), timeZone: Self.vienna)

        #expect(formatter.temperature(18) == "18°")
        #expect(formatter.spokenTemperature(18) == "18 degrees Celsius")
    }

    @Test func anExplicitFahrenheitOverrideBeatsTheRegion() {
        let formatter = WeatherFormatter(locale: Locale(identifier: "en-GB-u-mu-fahrenhe"), timeZone: Self.vienna)

        #expect(formatter.temperature(18) == "64°")
        #expect(formatter.spokenTemperature(18) == "64 degrees Fahrenheit")
    }

    @Test func britainMixesCelsiusWithMilesPerHour() {
        let formatter = WeatherFormatter(locale: Locale(identifier: "en_GB"), timeZone: Self.vienna)

        #expect(formatter.temperature(18) == "18°")
        #expect(formatter.gusts(60).contains("mph"))
    }

    @Test func spokenTemperatureAlsoAvoidsNegativeZero() {
        #expect(Self.metricFormatter.spokenTemperature(-0.4) == "0 degrees Celsius")
    }

    @Test func percentHasNoSeparatorBeforeTheSign() {
        #expect(Self.metricFormatter.percent(70) == "70%")
    }

    @Test func todayBelongsToTheForecastZoneNotThePhone() {
        let now = Self.date(2026, 9, 21, 23, 30, in: Self.toronto)
        let torontoDay = Self.date(2026, 9, 21, 0, in: Self.toronto)
        let torontoFormatter = WeatherFormatter(locale: Self.imperial, timeZone: Self.toronto)
        let viennaFormatter = WeatherFormatter(locale: Self.imperial, timeZone: Self.vienna)

        #expect(torontoFormatter.dayLabel(torontoDay, now: now) == "Today")
        #expect(viennaFormatter.dayLabel(torontoDay, now: now) == "Mon")
    }

    @Test func aLaterDayUsesItsAbbreviatedWeekday() {
        let now = Self.date(2026, 9, 21, 9, in: Self.vienna)
        let tuesday = Self.date(2026, 9, 22, 9, in: Self.vienna)

        #expect(Self.metricFormatter.dayLabel(tuesday, now: now) == "Tue")
    }

    @Test func spokenDayNameSaysTodayOrTheFullWeekday() {
        let now = Self.date(2026, 9, 21, 9, in: Self.vienna)
        let tuesday = Self.date(2026, 9, 22, 9, in: Self.vienna)

        #expect(Self.metricFormatter.spokenDayName(now, now: now) == "Today")
        #expect(Self.metricFormatter.spokenDayName(tuesday, now: now) == "Tuesday")
    }

    @Test func theHourContainingNowIsLabelledNow() {
        let now = Self.date(2026, 9, 21, 9, 30, in: Self.vienna)
        let sameHour = Self.date(2026, 9, 21, 9, in: Self.vienna)

        #expect(Self.metricFormatter.hourLabel(sameHour, now: now) == "Now")
    }

    @Test func aTwentyFourHourLocaleLabelsHoursWithTwoDigits() {
        let now = Self.date(2026, 9, 21, 9, 30, in: Self.vienna)
        let nextHour = Self.date(2026, 9, 21, 10, in: Self.vienna)

        #expect(Self.metricFormatter.hourLabel(nextHour, now: now) == "10")
    }

    @Test func aTwelveHourLocaleLabelsHoursWithAMOrPM() {
        let now = Self.date(2026, 9, 21, 9, 30, in: Self.vienna)
        let nextHour = Self.date(2026, 9, 21, 10, in: Self.vienna)
        let label = Self.imperialFormatter.hourLabel(nextHour, now: now)

        #expect(label.contains("AM") || label.contains("PM"))
    }

    @Test func theSameHourOnAnotherDayIsNotNow() {
        let now = Self.date(2026, 9, 21, 9, 30, in: Self.vienna)
        let tomorrow = Self.date(2026, 9, 22, 9, in: Self.vienna)

        #expect(Self.metricFormatter.hourLabel(tomorrow, now: now) != "Now")
    }

    @Test func clockUsesTwentyFourHourDigitsInAMetricLocale() {
        #expect(Self.metricFormatter.clock(Self.date(2026, 9, 21, 8, in: Self.vienna)) == "08:00")
    }

    @Test func clockUsesTwelveHourDigitsInAnImperialLocale() {
        let rendered = Self.normalized(Self.imperialFormatter.clock(Self.date(2026, 9, 21, 8, in: Self.vienna)))

        #expect(rendered == "8:00 AM")
    }

    @Test func conditionNamesCoverEveryCase() {
        let expected: [WeatherCondition: String] = [
            .clear: "Clear",
            .mostlyClear: "Mostly clear",
            .partlyCloudy: "Partly cloudy",
            .overcast: "Overcast",
            .fog: "Fog",
            .drizzle: "Drizzle",
            .freezingDrizzle: "Freezing drizzle",
            .rain: "Rain",
            .freezingRain: "Freezing rain",
            .snow: "Snow",
            .snowGrains: "Snow grains",
            .rainShowers: "Rain showers",
            .snowShowers: "Snow showers",
            .thunderstorm: "Thunderstorm",
            .thunderstormWithHail: "Thunderstorm with hail",
            .unknown: "Unknown"
        ]

        for condition in WeatherCondition.allCases {
            #expect(Self.metricFormatter.conditionName(condition) == expected[condition])
        }
    }

    @Test func precipitationSummarySpansItsClockTimes() {
        let summary = DaySummary.precipitation(
            kind: .rain,
            from: Self.date(2026, 9, 21, 8, in: Self.vienna),
            to: Self.date(2026, 9, 21, 10, in: Self.vienna)
        )

        #expect(Self.metricFormatter.summary(summary) == "Rain likely 08:00\u{2013}10:00")
    }

    @Test func snowAndThunderstormsNameTheirOwnKind() {
        let from = Self.date(2026, 9, 21, 8, in: Self.vienna)
        let to = Self.date(2026, 9, 21, 10, in: Self.vienna)

        #expect(
            Self.metricFormatter.summary(.precipitation(kind: .snow, from: from, to: to))
                == "Snow likely 08:00\u{2013}10:00"
        )
        #expect(
            Self.metricFormatter.summary(.precipitation(kind: .thunderstorm, from: from, to: to))
                == "Thunderstorms likely 08:00\u{2013}10:00"
        )
    }

    @Test func gustSummaryNamesTheHourAndThePeak() {
        let summary = DaySummary.gusts(peakKmh: 60, at: Self.date(2026, 9, 21, 15, in: Self.vienna))

        #expect(Self.metricFormatter.summary(summary) == "Windy around 15:00, gusts up to 60 km/h")
    }

    @Test func warmingSummaryNamesTheTemperatureAndTheHour() {
        let summary = DaySummary.warmingUp(toCelsius: 21, at: Self.date(2026, 9, 21, 15, in: Self.vienna))

        #expect(Self.metricFormatter.summary(summary) == "Warming up to 21° by 15:00")
    }

    @Test func conditionSummaryNamesTheConditionAndTheHigh() {
        let summary = DaySummary.conditionAndHigh(code: WeatherCode(wmo: 2), highCelsius: 21)

        #expect(Self.metricFormatter.summary(summary) == "Partly cloudy, high 21°")
    }

    @Test func spokenDayReadsAFullSentence() {
        let now = Self.date(2026, 9, 21, 9, in: Self.vienna)
        let day = DayForecast(
            date: Self.date(2026, 9, 22, 12, in: Self.vienna),
            code: WeatherCode(wmo: 61),
            highCelsius: 17,
            lowCelsius: 11,
            precipitationProbability: 70,
            sunrise: Self.date(2026, 9, 22, 7, in: Self.vienna),
            sunset: Self.date(2026, 9, 22, 19, in: Self.vienna)
        )

        #expect(
            Self.metricFormatter.spokenDay(day, now: now)
                == "Tuesday. Light rain, 70 percent chance. Low 11 degrees Celsius, high 17 degrees Celsius."
        )
    }

    @Test func spokenDayOmitsAnUnlikelyChance() {
        let now = Self.date(2026, 9, 21, 9, in: Self.vienna)
        let day = DayForecast(
            date: Self.date(2026, 9, 22, 12, in: Self.vienna),
            code: WeatherCode(wmo: 61),
            highCelsius: 17,
            lowCelsius: 11,
            precipitationProbability: 10,
            sunrise: Self.date(2026, 9, 22, 7, in: Self.vienna),
            sunset: Self.date(2026, 9, 22, 19, in: Self.vienna)
        )

        #expect(
            Self.metricFormatter.spokenDay(day, now: now)
                == "Tuesday. Light rain. Low 11 degrees Celsius, high 17 degrees Celsius."
        )
    }

    @Test func spokenDayKeepsTheChanceAtTwentyPercent() {
        let now = Self.date(2026, 9, 21, 9, in: Self.vienna)
        let day = DayForecast(
            date: Self.date(2026, 9, 22, 12, in: Self.vienna),
            code: WeatherCode(wmo: 3),
            highCelsius: 17,
            lowCelsius: 11,
            precipitationProbability: 20,
            sunrise: Self.date(2026, 9, 22, 7, in: Self.vienna),
            sunset: Self.date(2026, 9, 22, 19, in: Self.vienna)
        )

        #expect(
            Self.metricFormatter.spokenDay(day, now: now)
                == "Tuesday. Overcast, 20 percent chance. Low 11 degrees Celsius, high 17 degrees Celsius."
        )
    }

    @Test func spokenDayForTodaySaysToday() {
        let now = Self.date(2026, 9, 21, 9, in: Self.vienna)
        let day = DayForecast(
            date: Self.date(2026, 9, 21, 12, in: Self.vienna),
            code: WeatherCode(wmo: 0),
            highCelsius: 17,
            lowCelsius: 11,
            precipitationProbability: 0,
            sunrise: Self.date(2026, 9, 21, 7, in: Self.vienna),
            sunset: Self.date(2026, 9, 21, 19, in: Self.vienna)
        )

        #expect(Self.metricFormatter.spokenDay(day, now: now).hasPrefix("Today. Clear."))
    }

    @Test func updatedAgoCountsWholeHoursBack() {
        let now = Self.date(2026, 9, 21, 12, in: Self.vienna)
        let rendered = Self.metricFormatter.updatedAgo(now.addingTimeInterval(-2 * 3600), now: now)

        #expect(rendered.hasPrefix("Updated "))
        #expect(rendered.contains("2"))
        #expect(rendered.lowercased().contains("hr") || rendered.lowercased().contains("hour"))
    }

    @Test func updatedAgoFollowsTheFormatterLocale() {
        let now = Self.date(2026, 9, 21, 12, in: Self.vienna)
        let formatter = WeatherFormatter(locale: Locale(identifier: "de_AT"), timeZone: Self.vienna)
        let rendered = formatter.updatedAgo(now.addingTimeInterval(-2 * 3600), now: now)

        #expect(rendered.contains("2"))
        #expect(rendered.contains("Std"))
    }

    @Test func updatedAgoCountsMinutes() {
        let now = Self.date(2026, 9, 21, 12, in: Self.vienna)
        let rendered = Self.metricFormatter.updatedAgo(now.addingTimeInterval(-45 * 60), now: now)

        #expect(rendered.hasPrefix("Updated "))
        #expect(rendered.contains("45"))
    }
}
