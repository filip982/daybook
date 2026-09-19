import Foundation
import Testing
@testable import WeatherFeature

@Suite struct DaySummaryTests {
    static let now = ForecastBuilder.now
    static func hour(_ offset: Int) -> Date { ForecastBuilder().hour(offset) }

    @Test func contiguousRainRunSpansItsHoursPlusOne() {
        let forecast = ForecastBuilder()
            .overriding(2, code: WeatherCode(wmo: 61), precipitationProbability: 70)
            .overriding(3, code: WeatherCode(wmo: 61), precipitationProbability: 70)
            .overriding(4, code: WeatherCode(wmo: 61), precipitationProbability: 70)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .precipitation(kind: .rain, from: Self.hour(2), to: Self.hour(5))
        )
    }

    @Test func onlyTheFirstRunCounts() {
        let forecast = ForecastBuilder()
            .overriding(2, code: WeatherCode(wmo: 61), precipitationProbability: 60)
            .overriding(3, precipitationProbability: 10)
            .overriding(4, code: WeatherCode(wmo: 61), precipitationProbability: 90)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .precipitation(kind: .rain, from: Self.hour(2), to: Self.hour(3))
        )
    }

    @Test func thunderstormAnywhereInRunWins() {
        let forecast = ForecastBuilder()
            .overriding(2, code: WeatherCode(wmo: 61), precipitationProbability: 70)
            .overriding(3, code: WeatherCode(wmo: 95), precipitationProbability: 70)
            .overriding(4, code: WeatherCode(wmo: 71), precipitationProbability: 70)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .precipitation(kind: .thunderstorm, from: Self.hour(2), to: Self.hour(5))
        )
    }

    @Test func snowBeatsRainWhenNoThunderstorm() {
        let forecast = ForecastBuilder()
            .overriding(2, code: WeatherCode(wmo: 71), precipitationProbability: 70)
            .overriding(3, code: WeatherCode(wmo: 71), precipitationProbability: 70)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .precipitation(kind: .snow, from: Self.hour(2), to: Self.hour(4))
        )
    }

    @Test func probabilityBelowFiftyIsNotPrecipitation() {
        let forecast = (0..<24).reduce(ForecastBuilder()) { builder, offset in
            builder.overriding(offset, code: WeatherCode(wmo: 61), precipitationProbability: 49)
        }.build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func precipitationBeyondTheWindowIsIgnored() {
        let forecast = ForecastBuilder()
            .overriding(13, code: WeatherCode(wmo: 61), precipitationProbability: 80)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func precipitationBeatsGusts() {
        let forecast = ForecastBuilder()
            .overriding(1, windGustsKmh: 80)
            .overriding(6, code: WeatherCode(wmo: 61), precipitationProbability: 70)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .precipitation(kind: .rain, from: Self.hour(6), to: Self.hour(7))
        )
    }

    @Test func gustsAtThresholdReport() {
        let forecast = ForecastBuilder().overriding(5, windGustsKmh: 50).build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .gusts(peakKmh: 50, at: Self.hour(5))
        )
    }

    @Test func gustsBelowThresholdFallThrough() {
        let forecast = ForecastBuilder().overriding(5, windGustsKmh: 49.9).build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func gustTiesTakeTheEarliestHour() {
        let forecast = ForecastBuilder()
            .overriding(3, windGustsKmh: 60)
            .overriding(7, windGustsKmh: 60)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .gusts(peakKmh: 60, at: Self.hour(3))
        )
    }

    @Test func warmingUpAtThresholdReports() {
        let forecast = ForecastBuilder()
            .withCurrentTemperature(10)
            .overriding(6, temperatureCelsius: 18)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .warmingUp(toCelsius: 18, at: Self.hour(6))
        )
    }

    @Test func warmingUpBelowThresholdFallsThrough() {
        let forecast = ForecastBuilder()
            .withCurrentTemperature(10)
            .overriding(6, temperatureCelsius: 17.9)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func warmingUpTiesTakeTheEarliestHour() {
        let forecast = ForecastBuilder()
            .withCurrentTemperature(10)
            .overriding(4, temperatureCelsius: 20)
            .overriding(9, temperatureCelsius: 20)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .warmingUp(toCelsius: 20, at: Self.hour(4))
        )
    }

    @Test func calmDayReportsConditionAndHigh() {
        let forecast = ForecastBuilder().build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func emptyDailyOnACalmDayIsNil() {
        let forecast = ForecastBuilder().withDaily([]).build()

        #expect(DaySummary.make(from: forecast, now: Self.now) == nil)
    }

    @Test func entryExactlyOneHourBeforeNowIsOutsideTheWindow() {
        let forecast = ForecastBuilder()
            .withHourOffsets(Array(-1..<24))
            .overriding(-1, windGustsKmh: 90)
            .build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func entryJustAfterOneHourBeforeNowIsInsideTheWindow() {
        let forecast = ForecastBuilder()
            .withHourOffsets(Array(-1..<24))
            .overriding(-1, windGustsKmh: 90)
            .build()
        let shiftedNow = Self.now.addingTimeInterval(-1)

        #expect(
            DaySummary.make(from: forecast, now: shiftedNow)
                == .gusts(peakKmh: 90, at: Self.hour(-1))
        )
    }

    @Test func entryExactlyTwelveHoursAfterNowIsOutsideTheWindow() {
        let forecast = ForecastBuilder().overriding(12, windGustsKmh: 90).build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .conditionAndHigh(code: WeatherCode(wmo: 1), highCelsius: 18)
        )
    }

    @Test func entryJustBeforeTwelveHoursAfterNowIsInsideTheWindow() {
        let forecast = ForecastBuilder().overriding(11, windGustsKmh: 90).build()

        #expect(
            DaySummary.make(from: forecast, now: Self.now)
                == .gusts(peakKmh: 90, at: Self.hour(11))
        )
    }
}
