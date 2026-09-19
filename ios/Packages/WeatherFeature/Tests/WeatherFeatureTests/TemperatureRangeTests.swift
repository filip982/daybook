import Foundation
import Testing
@testable import WeatherFeature

@Suite struct TemperatureRangeTests {
    static let span = TemperatureSpan(minimum: 5, maximum: 25)

    @Test func lowAndHighMapIntoTheSpan() {
        let fractions = Self.span.fractions(low: 10, high: 20)
        #expect(fractions.start == 0.25)
        #expect(fractions.end == 0.75)
    }

    @Test func theSpanEndsMapToZeroAndOne() {
        let fractions = Self.span.fractions(low: 5, high: 25)
        #expect(fractions.start == 0)
        #expect(fractions.end == 1)
    }

    @Test func valuesOutsideTheSpanClampIntoTheBar() {
        let fractions = Self.span.fractions(low: -10, high: 40)
        #expect(fractions.start == 0)
        #expect(fractions.end == 1)
    }

    @Test func aDegenerateSpanFillsTheWholeBar() {
        let fractions = TemperatureSpan(minimum: 12, maximum: 12).fractions(low: 12, high: 12)
        #expect(fractions.start == 0)
        #expect(fractions.end == 1)
    }

    @Test func aSingleTemperatureMapsToAPointOnTheBar() {
        #expect(Self.span.fraction(of: 15) == 0.5)
        #expect(TemperatureSpan(minimum: 12, maximum: 12).fraction(of: 12) == 0)
    }

    @Test func theSpanCoversEveryDayInTheForecast() {
        let span = TemperatureSpan(days: Forecast.fixtureVienna.daily)
        #expect(span.minimum == 7)
        #expect(span.maximum == 23)
    }

    @Test func anEmptyForecastStillProducesAUsableSpan() {
        let span = TemperatureSpan(days: [])
        #expect(span.fractions(low: 0, high: 0).start == 0)
        #expect(span.fractions(low: 0, high: 0).end == 1)
    }
}
