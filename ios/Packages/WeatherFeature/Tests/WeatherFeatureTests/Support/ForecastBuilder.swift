import Foundation
@testable import WeatherFeature

struct ForecastBuilder {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)
    static let calmTemperatureCelsius: Double = 15

    private struct HourOverride {
        var temperatureCelsius: Double?
        var code: WeatherCode?
        var precipitationProbability: Int?
        var windGustsKmh: Double?
    }

    var now: Date = ForecastBuilder.now
    var currentTemperatureCelsius: Double = ForecastBuilder.calmTemperatureCelsius
    var hourOffsets: [Int] = Array(0..<24)
    var daily: [DayForecast] = [
        DayForecast(
            date: ForecastBuilder.now,
            code: WeatherCode(wmo: 1),
            highCelsius: 18,
            lowCelsius: 9,
            precipitationProbability: 10,
            sunrise: ForecastBuilder.now,
            sunset: ForecastBuilder.now.addingTimeInterval(12 * 3600)
        )
    ]

    private var overrides: [Int: HourOverride] = [:]

    func hour(_ offset: Int) -> Date {
        now.addingTimeInterval(Double(offset) * 3600)
    }

    func overriding(
        _ offset: Int,
        temperatureCelsius: Double? = nil,
        code: WeatherCode? = nil,
        precipitationProbability: Int? = nil,
        windGustsKmh: Double? = nil
    ) -> ForecastBuilder {
        var copy = self
        copy.overrides[offset] = HourOverride(
            temperatureCelsius: temperatureCelsius,
            code: code,
            precipitationProbability: precipitationProbability,
            windGustsKmh: windGustsKmh
        )
        return copy
    }

    func withCurrentTemperature(_ celsius: Double) -> ForecastBuilder {
        var copy = self
        copy.currentTemperatureCelsius = celsius
        return copy
    }

    func withDaily(_ daily: [DayForecast]) -> ForecastBuilder {
        var copy = self
        copy.daily = daily
        return copy
    }

    func withHourOffsets(_ offsets: [Int]) -> ForecastBuilder {
        var copy = self
        copy.hourOffsets = offsets
        return copy
    }

    func build() -> Forecast {
        let hourly = hourOffsets.map { offset in
            let override = overrides[offset]
            return HourForecast(
                time: hour(offset),
                temperatureCelsius: override?.temperatureCelsius ?? Self.calmTemperatureCelsius,
                code: override?.code ?? WeatherCode(wmo: 1),
                isDay: true,
                precipitationProbability: override?.precipitationProbability ?? 0,
                windGustsKmh: override?.windGustsKmh ?? 10
            )
        }

        return Forecast(
            timeZone: TimeZone(identifier: "Europe/Berlin")!,
            current: CurrentConditions(
                temperatureCelsius: currentTemperatureCelsius,
                apparentTemperatureCelsius: currentTemperatureCelsius - 2,
                code: WeatherCode(wmo: 1),
                isDay: true,
                windSpeedKmh: 8,
                windGustsKmh: 10
            ),
            hourly: hourly,
            daily: daily,
            fetchedAt: now
        )
    }
}
