import Foundation
import Testing
@testable import WeatherFeature

@Suite struct ForecastTests {
    static let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

    static func makeForecast(fetchedAt: Date = ForecastTests.fetchedAt) -> Forecast {
        Forecast(
            timeZone: TimeZone(identifier: "Europe/Berlin")!,
            current: CurrentConditions(
                temperatureCelsius: 12.5,
                apparentTemperatureCelsius: 10.5,
                code: WeatherCode(wmo: 61),
                isDay: true,
                windSpeedKmh: 14,
                windGustsKmh: 32
            ),
            hourly: [
                HourForecast(
                    time: fetchedAt.addingTimeInterval(3600),
                    temperatureCelsius: 13,
                    code: WeatherCode(wmo: 3),
                    isDay: true,
                    precipitationProbability: 40,
                    windGustsKmh: 28
                )
            ],
            daily: [
                DayForecast(
                    date: fetchedAt,
                    code: WeatherCode(wmo: 80),
                    highCelsius: 16,
                    lowCelsius: 7,
                    precipitationProbability: 65,
                    sunrise: fetchedAt.addingTimeInterval(1800),
                    sunset: fetchedAt.addingTimeInterval(40000)
                )
            ],
            fetchedAt: fetchedAt
        )
    }

    @Test(arguments: [
        (29 * 60 + 59, false),
        (30 * 60, true),
        (2 * 3600, true),
        (-60, false),
    ] as [(TimeInterval, Bool)])
    func isStaleAcrossTimeToLive(offset: TimeInterval, expected: Bool) {
        let forecast = Self.makeForecast()
        #expect(forecast.isStale(now: Self.fetchedAt.addingTimeInterval(offset)) == expected)
    }

    @Test func survivesJSONRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = Self.makeForecast()
        let decoded = try decoder.decode(Forecast.self, from: encoder.encode(original))

        #expect(decoded == original)
    }

    @Test func weatherCodeEncodesAsBareInteger() throws {
        let data = try JSONEncoder().encode(WeatherCode(wmo: 61))
        #expect(String(decoding: data, as: UTF8.self) == "61")
        #expect(try JSONDecoder().decode(WeatherCode.self, from: data) == WeatherCode(wmo: 61))
    }
}
