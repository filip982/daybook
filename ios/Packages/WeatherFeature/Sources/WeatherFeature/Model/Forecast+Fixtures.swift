#if DEBUG
import DaybookPlatform
import Foundation

private func gregorian(in zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

private func date(
    _ zone: String,
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0
) -> Date {
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return gregorian(in: zone).date(from: components)!
}

private struct FixtureDay {
    let low: Double
    let high: Double
    let wmo: Int
    let precipitationProbability: Int
    let sunriseHour: Int
    let sunriseMinute: Int
    let sunsetHour: Int
    let sunsetMinute: Int
}

private func days(
    _ zone: String,
    from start: Date,
    _ entries: [FixtureDay]
) -> [DayForecast] {
    let calendar = gregorian(in: zone)
    return entries.enumerated().map { offset, entry in
        let day = calendar.date(byAdding: .day, value: offset, to: start)!
        return DayForecast(
            date: day,
            code: WeatherCode(wmo: entry.wmo),
            highCelsius: entry.high,
            lowCelsius: entry.low,
            precipitationProbability: entry.precipitationProbability,
            sunrise: calendar.date(bySettingHour: entry.sunriseHour, minute: entry.sunriseMinute, second: 0, of: day)!,
            sunset: calendar.date(bySettingHour: entry.sunsetHour, minute: entry.sunsetMinute, second: 0, of: day)!
        )
    }
}

private func startOfHourContainingFixtureNow(_ zone: String) -> Date {
    let calendar = gregorian(in: zone)
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: Forecast.fixtureNow)
    return calendar.date(from: components)!
}

private func startOfDayContainingFixtureNow(_ zone: String) -> Date {
    gregorian(in: zone).startOfDay(for: Forecast.fixtureNow)
}

private struct FixtureHour {
    let temperature: Double
    let wmo: Int
    let isDay: Bool
    let precipitationProbability: Int
    let gustsKmh: Double
}

private func hours(from start: Date, _ entries: [FixtureHour]) -> [HourForecast] {
    entries.enumerated().map { offset, entry in
        HourForecast(
            time: start.addingTimeInterval(Double(offset) * 3600),
            temperatureCelsius: entry.temperature,
            code: WeatherCode(wmo: entry.wmo),
            isDay: entry.isDay,
            precipitationProbability: entry.precipitationProbability,
            windGustsKmh: entry.gustsKmh
        )
    }
}

extension Forecast {
    static let fixtureNow = date("Europe/Vienna", 2026, 9, 21, 9, 41)

    static let fixtureVienna = Forecast(
        timeZone: TimeZone(identifier: "Europe/Vienna")!,
        current: CurrentConditions(
            temperatureCelsius: 18,
            apparentTemperatureCelsius: 17,
            code: WeatherCode(wmo: 2),
            isDay: true,
            windSpeedKmh: 11,
            windGustsKmh: 19
        ),
        hourly: hours(
            from: startOfHourContainingFixtureNow("Europe/Vienna"),
            [
                FixtureHour(temperature: 18, wmo: 2, isDay: true, precipitationProbability: 5, gustsKmh: 18),
                FixtureHour(temperature: 19, wmo: 2, isDay: true, precipitationProbability: 5, gustsKmh: 19),
                FixtureHour(temperature: 20, wmo: 2, isDay: true, precipitationProbability: 10, gustsKmh: 21),
                FixtureHour(temperature: 21, wmo: 2, isDay: true, precipitationProbability: 10, gustsKmh: 23),
                FixtureHour(temperature: 21, wmo: 3, isDay: true, precipitationProbability: 15, gustsKmh: 24),
                FixtureHour(temperature: 20, wmo: 3, isDay: true, precipitationProbability: 20, gustsKmh: 24),
                FixtureHour(temperature: 19, wmo: 3, isDay: true, precipitationProbability: 25, gustsKmh: 22),
                FixtureHour(temperature: 18, wmo: 3, isDay: true, precipitationProbability: 25, gustsKmh: 21),
                FixtureHour(temperature: 17, wmo: 2, isDay: true, precipitationProbability: 20, gustsKmh: 19),
                FixtureHour(temperature: 16, wmo: 2, isDay: true, precipitationProbability: 15, gustsKmh: 17),
                FixtureHour(temperature: 15, wmo: 1, isDay: false, precipitationProbability: 10, gustsKmh: 15),
                FixtureHour(temperature: 14, wmo: 1, isDay: false, precipitationProbability: 10, gustsKmh: 14),
                FixtureHour(temperature: 13, wmo: 1, isDay: false, precipitationProbability: 10, gustsKmh: 13),
                FixtureHour(temperature: 13, wmo: 2, isDay: false, precipitationProbability: 15, gustsKmh: 13),
                FixtureHour(temperature: 12, wmo: 2, isDay: false, precipitationProbability: 20, gustsKmh: 12),
                FixtureHour(temperature: 12, wmo: 3, isDay: false, precipitationProbability: 25, gustsKmh: 12),
                FixtureHour(temperature: 11, wmo: 3, isDay: false, precipitationProbability: 30, gustsKmh: 13),
                FixtureHour(temperature: 11, wmo: 3, isDay: false, precipitationProbability: 35, gustsKmh: 14),
                FixtureHour(temperature: 11, wmo: 3, isDay: false, precipitationProbability: 40, gustsKmh: 15),
                FixtureHour(temperature: 12, wmo: 3, isDay: false, precipitationProbability: 45, gustsKmh: 16),
                FixtureHour(temperature: 13, wmo: 3, isDay: true, precipitationProbability: 45, gustsKmh: 18),
                FixtureHour(temperature: 15, wmo: 3, isDay: true, precipitationProbability: 40, gustsKmh: 20),
                FixtureHour(temperature: 16, wmo: 3, isDay: true, precipitationProbability: 40, gustsKmh: 22),
                FixtureHour(temperature: 17, wmo: 61, isDay: true, precipitationProbability: 45, gustsKmh: 24),
            ]
        ),
        daily: days(
            "Europe/Vienna",
            from: startOfDayContainingFixtureNow("Europe/Vienna"),
            [
                FixtureDay(low: 11, high: 21, wmo: 2, precipitationProbability: 15,
                           sunriseHour: 6, sunriseMinute: 40, sunsetHour: 18, sunsetMinute: 55),
                FixtureDay(low: 11, high: 17, wmo: 61, precipitationProbability: 70,
                           sunriseHour: 6, sunriseMinute: 42, sunsetHour: 18, sunsetMinute: 53),
                FixtureDay(low: 9, high: 15, wmo: 61, precipitationProbability: 55,
                           sunriseHour: 6, sunriseMinute: 43, sunsetHour: 18, sunsetMinute: 50),
                FixtureDay(low: 8, high: 16, wmo: 3, precipitationProbability: 25,
                           sunriseHour: 6, sunriseMinute: 45, sunsetHour: 18, sunsetMinute: 48),
                FixtureDay(low: 7, high: 18, wmo: 2, precipitationProbability: 10,
                           sunriseHour: 6, sunriseMinute: 46, sunsetHour: 18, sunsetMinute: 46),
                FixtureDay(low: 10, high: 22, wmo: 0, precipitationProbability: 0,
                           sunriseHour: 6, sunriseMinute: 48, sunsetHour: 18, sunsetMinute: 43),
                FixtureDay(low: 12, high: 23, wmo: 0, precipitationProbability: 0,
                           sunriseHour: 6, sunriseMinute: 49, sunsetHour: 18, sunsetMinute: 41),
                FixtureDay(low: 11, high: 20, wmo: 2, precipitationProbability: 10,
                           sunriseHour: 6, sunriseMinute: 51, sunsetHour: 18, sunsetMinute: 39),
                FixtureDay(low: 10, high: 19, wmo: 3, precipitationProbability: 20,
                           sunriseHour: 6, sunriseMinute: 52, sunsetHour: 18, sunsetMinute: 36),
                FixtureDay(low: 9, high: 18, wmo: 61, precipitationProbability: 60,
                           sunriseHour: 6, sunriseMinute: 54, sunsetHour: 18, sunsetMinute: 34),
            ]
        ),
        fetchedAt: fixtureNow.addingTimeInterval(-5 * 60)
    )

    static let fixtureToronto = Forecast(
        timeZone: TimeZone(identifier: "America/Toronto")!,
        current: CurrentConditions(
            temperatureCelsius: 12,
            apparentTemperatureCelsius: 11,
            code: WeatherCode(wmo: 0),
            isDay: false,
            windSpeedKmh: 7,
            windGustsKmh: 14
        ),
        hourly: hours(
            from: startOfHourContainingFixtureNow("America/Toronto"),
            [
                FixtureHour(temperature: 12, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 14),
                FixtureHour(temperature: 11, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 13),
                FixtureHour(temperature: 11, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 12),
                FixtureHour(temperature: 10, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 12),
                FixtureHour(temperature: 10, wmo: 1, isDay: true, precipitationProbability: 0, gustsKmh: 13),
                FixtureHour(temperature: 12, wmo: 1, isDay: true, precipitationProbability: 0, gustsKmh: 15),
                FixtureHour(temperature: 14, wmo: 1, isDay: true, precipitationProbability: 0, gustsKmh: 17),
                FixtureHour(temperature: 15, wmo: 2, isDay: true, precipitationProbability: 5, gustsKmh: 18),
                FixtureHour(temperature: 16, wmo: 2, isDay: true, precipitationProbability: 5, gustsKmh: 20),
                FixtureHour(temperature: 17, wmo: 2, isDay: true, precipitationProbability: 10, gustsKmh: 21),
                FixtureHour(temperature: 18, wmo: 2, isDay: true, precipitationProbability: 10, gustsKmh: 22),
                FixtureHour(temperature: 19, wmo: 2, isDay: true, precipitationProbability: 10, gustsKmh: 23),
                FixtureHour(temperature: 19, wmo: 2, isDay: true, precipitationProbability: 15, gustsKmh: 23),
                FixtureHour(temperature: 18, wmo: 2, isDay: true, precipitationProbability: 15, gustsKmh: 22),
                FixtureHour(temperature: 17, wmo: 1, isDay: true, precipitationProbability: 10, gustsKmh: 20),
                FixtureHour(temperature: 16, wmo: 1, isDay: true, precipitationProbability: 10, gustsKmh: 18),
                FixtureHour(temperature: 15, wmo: 1, isDay: true, precipitationProbability: 5, gustsKmh: 16),
                FixtureHour(temperature: 14, wmo: 0, isDay: true, precipitationProbability: 5, gustsKmh: 15),
                FixtureHour(temperature: 13, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 14),
                FixtureHour(temperature: 13, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 13),
                FixtureHour(temperature: 12, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 12),
                FixtureHour(temperature: 12, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 12),
                FixtureHour(temperature: 11, wmo: 1, isDay: false, precipitationProbability: 5, gustsKmh: 11),
                FixtureHour(temperature: 11, wmo: 1, isDay: false, precipitationProbability: 5, gustsKmh: 11),
            ]
        ),
        daily: days(
            "America/Toronto",
            from: startOfDayContainingFixtureNow("America/Toronto"),
            [
                FixtureDay(low: 10, high: 19, wmo: 0, precipitationProbability: 5,
                           sunriseHour: 7, sunriseMinute: 4, sunsetHour: 19, sunsetMinute: 16),
                FixtureDay(low: 11, high: 20, wmo: 1, precipitationProbability: 10,
                           sunriseHour: 7, sunriseMinute: 5, sunsetHour: 19, sunsetMinute: 14),
                FixtureDay(low: 12, high: 21, wmo: 2, precipitationProbability: 20,
                           sunriseHour: 7, sunriseMinute: 6, sunsetHour: 19, sunsetMinute: 12),
                FixtureDay(low: 13, high: 19, wmo: 61, precipitationProbability: 65,
                           sunriseHour: 7, sunriseMinute: 8, sunsetHour: 19, sunsetMinute: 11),
                FixtureDay(low: 10, high: 16, wmo: 3, precipitationProbability: 35,
                           sunriseHour: 7, sunriseMinute: 9, sunsetHour: 19, sunsetMinute: 9),
                FixtureDay(low: 8, high: 17, wmo: 2, precipitationProbability: 15,
                           sunriseHour: 7, sunriseMinute: 10, sunsetHour: 19, sunsetMinute: 7),
                FixtureDay(low: 9, high: 18, wmo: 0, precipitationProbability: 5,
                           sunriseHour: 7, sunriseMinute: 11, sunsetHour: 19, sunsetMinute: 5),
                FixtureDay(low: 11, high: 20, wmo: 1, precipitationProbability: 10,
                           sunriseHour: 7, sunriseMinute: 13, sunsetHour: 19, sunsetMinute: 3),
                FixtureDay(low: 12, high: 19, wmo: 3, precipitationProbability: 30,
                           sunriseHour: 7, sunriseMinute: 14, sunsetHour: 19, sunsetMinute: 2),
                FixtureDay(low: 10, high: 17, wmo: 61, precipitationProbability: 55,
                           sunriseHour: 7, sunriseMinute: 15, sunsetHour: 19, sunsetMinute: 0),
            ]
        ),
        fetchedAt: fixtureNow.addingTimeInterval(-2 * 3600)
    )

    static let fixtureLisbon = Forecast(
        timeZone: TimeZone(identifier: "Europe/Lisbon")!,
        current: CurrentConditions(
            temperatureCelsius: 22,
            apparentTemperatureCelsius: 22,
            code: WeatherCode(wmo: 0),
            isDay: true,
            windSpeedKmh: 13,
            windGustsKmh: 21
        ),
        hourly: hours(
            from: startOfHourContainingFixtureNow("Europe/Lisbon"),
            [
                FixtureHour(temperature: 22, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 20),
                FixtureHour(temperature: 23, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 21),
                FixtureHour(temperature: 24, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 23),
                FixtureHour(temperature: 25, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 25),
                FixtureHour(temperature: 26, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 26),
                FixtureHour(temperature: 26, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 27),
                FixtureHour(temperature: 25, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 27),
                FixtureHour(temperature: 25, wmo: 1, isDay: true, precipitationProbability: 0, gustsKmh: 26),
                FixtureHour(temperature: 24, wmo: 1, isDay: true, precipitationProbability: 0, gustsKmh: 25),
                FixtureHour(temperature: 23, wmo: 1, isDay: true, precipitationProbability: 0, gustsKmh: 23),
                FixtureHour(temperature: 22, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 21),
                FixtureHour(temperature: 21, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 19),
                FixtureHour(temperature: 20, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 18),
                FixtureHour(temperature: 20, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 17),
                FixtureHour(temperature: 19, wmo: 0, isDay: false, precipitationProbability: 0, gustsKmh: 16),
                FixtureHour(temperature: 19, wmo: 0, isDay: false, precipitationProbability: 5, gustsKmh: 15),
                FixtureHour(temperature: 18, wmo: 1, isDay: false, precipitationProbability: 5, gustsKmh: 15),
                FixtureHour(temperature: 18, wmo: 1, isDay: false, precipitationProbability: 5, gustsKmh: 14),
                FixtureHour(temperature: 17, wmo: 1, isDay: false, precipitationProbability: 10, gustsKmh: 14),
                FixtureHour(temperature: 17, wmo: 1, isDay: false, precipitationProbability: 10, gustsKmh: 15),
                FixtureHour(temperature: 18, wmo: 0, isDay: true, precipitationProbability: 5, gustsKmh: 16),
                FixtureHour(temperature: 20, wmo: 0, isDay: true, precipitationProbability: 5, gustsKmh: 18),
                FixtureHour(temperature: 22, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 20),
                FixtureHour(temperature: 24, wmo: 0, isDay: true, precipitationProbability: 0, gustsKmh: 22),
            ]
        ),
        daily: days(
            "Europe/Lisbon",
            from: startOfDayContainingFixtureNow("Europe/Lisbon"),
            [
                FixtureDay(low: 17, high: 26, wmo: 0, precipitationProbability: 0,
                           sunriseHour: 7, sunriseMinute: 15, sunsetHour: 19, sunsetMinute: 26),
                FixtureDay(low: 17, high: 27, wmo: 0, precipitationProbability: 0,
                           sunriseHour: 7, sunriseMinute: 16, sunsetHour: 19, sunsetMinute: 24),
                FixtureDay(low: 18, high: 27, wmo: 1, precipitationProbability: 5,
                           sunriseHour: 7, sunriseMinute: 17, sunsetHour: 19, sunsetMinute: 22),
                FixtureDay(low: 18, high: 25, wmo: 2, precipitationProbability: 15,
                           sunriseHour: 7, sunriseMinute: 18, sunsetHour: 19, sunsetMinute: 21),
                FixtureDay(low: 17, high: 24, wmo: 2, precipitationProbability: 20,
                           sunriseHour: 7, sunriseMinute: 19, sunsetHour: 19, sunsetMinute: 19),
                FixtureDay(low: 16, high: 24, wmo: 1, precipitationProbability: 10,
                           sunriseHour: 7, sunriseMinute: 20, sunsetHour: 19, sunsetMinute: 17),
                FixtureDay(low: 16, high: 25, wmo: 0, precipitationProbability: 0,
                           sunriseHour: 7, sunriseMinute: 21, sunsetHour: 19, sunsetMinute: 15),
                FixtureDay(low: 17, high: 26, wmo: 0, precipitationProbability: 0,
                           sunriseHour: 7, sunriseMinute: 22, sunsetHour: 19, sunsetMinute: 14),
                FixtureDay(low: 17, high: 25, wmo: 1, precipitationProbability: 5,
                           sunriseHour: 7, sunriseMinute: 23, sunsetHour: 19, sunsetMinute: 12),
                FixtureDay(low: 16, high: 23, wmo: 3, precipitationProbability: 25,
                           sunriseHour: 7, sunriseMinute: 24, sunsetHour: 19, sunsetMinute: 10),
            ]
        ),
        fetchedAt: fixtureNow.addingTimeInterval(-5 * 60)
    )

    static let fixtureOslo = Forecast(
        timeZone: TimeZone(identifier: "Europe/Oslo")!,
        current: CurrentConditions(
            temperatureCelsius: 9,
            apparentTemperatureCelsius: 6,
            code: WeatherCode(wmo: 61),
            isDay: true,
            windSpeedKmh: 16,
            windGustsKmh: 29
        ),
        hourly: hours(
            from: startOfHourContainingFixtureNow("Europe/Oslo"),
            [
                FixtureHour(temperature: 9, wmo: 61, isDay: true, precipitationProbability: 70, gustsKmh: 28),
                FixtureHour(temperature: 9, wmo: 61, isDay: true, precipitationProbability: 75, gustsKmh: 30),
                FixtureHour(temperature: 10, wmo: 61, isDay: true, precipitationProbability: 80, gustsKmh: 31),
                FixtureHour(temperature: 10, wmo: 61, isDay: true, precipitationProbability: 80, gustsKmh: 31),
                FixtureHour(temperature: 11, wmo: 61, isDay: true, precipitationProbability: 70, gustsKmh: 29),
                FixtureHour(temperature: 11, wmo: 61, isDay: true, precipitationProbability: 60, gustsKmh: 27),
                FixtureHour(temperature: 10, wmo: 3, isDay: true, precipitationProbability: 40, gustsKmh: 25),
                FixtureHour(temperature: 10, wmo: 3, isDay: true, precipitationProbability: 30, gustsKmh: 23),
                FixtureHour(temperature: 9, wmo: 3, isDay: true, precipitationProbability: 25, gustsKmh: 22),
                FixtureHour(temperature: 9, wmo: 3, isDay: true, precipitationProbability: 20, gustsKmh: 20),
                FixtureHour(temperature: 8, wmo: 3, isDay: false, precipitationProbability: 20, gustsKmh: 19),
                FixtureHour(temperature: 8, wmo: 3, isDay: false, precipitationProbability: 15, gustsKmh: 18),
                FixtureHour(temperature: 7, wmo: 2, isDay: false, precipitationProbability: 15, gustsKmh: 17),
                FixtureHour(temperature: 7, wmo: 2, isDay: false, precipitationProbability: 10, gustsKmh: 16),
                FixtureHour(temperature: 7, wmo: 2, isDay: false, precipitationProbability: 10, gustsKmh: 15),
                FixtureHour(temperature: 6, wmo: 2, isDay: false, precipitationProbability: 10, gustsKmh: 14),
                FixtureHour(temperature: 6, wmo: 3, isDay: false, precipitationProbability: 15, gustsKmh: 14),
                FixtureHour(temperature: 6, wmo: 3, isDay: false, precipitationProbability: 20, gustsKmh: 15),
                FixtureHour(temperature: 6, wmo: 3, isDay: false, precipitationProbability: 25, gustsKmh: 16),
                FixtureHour(temperature: 7, wmo: 3, isDay: false, precipitationProbability: 30, gustsKmh: 17),
                FixtureHour(temperature: 7, wmo: 61, isDay: true, precipitationProbability: 40, gustsKmh: 19),
                FixtureHour(temperature: 8, wmo: 61, isDay: true, precipitationProbability: 45, gustsKmh: 21),
                FixtureHour(temperature: 9, wmo: 3, isDay: true, precipitationProbability: 35, gustsKmh: 22),
                FixtureHour(temperature: 10, wmo: 3, isDay: true, precipitationProbability: 30, gustsKmh: 23),
            ]
        ),
        daily: days(
            "Europe/Oslo",
            from: startOfDayContainingFixtureNow("Europe/Oslo"),
            [
                FixtureDay(low: 6, high: 11, wmo: 61, precipitationProbability: 80,
                           sunriseHour: 7, sunriseMinute: 2, sunsetHour: 19, sunsetMinute: 18),
                FixtureDay(low: 6, high: 12, wmo: 61, precipitationProbability: 60,
                           sunriseHour: 7, sunriseMinute: 4, sunsetHour: 19, sunsetMinute: 15),
                FixtureDay(low: 5, high: 12, wmo: 3, precipitationProbability: 35,
                           sunriseHour: 7, sunriseMinute: 6, sunsetHour: 19, sunsetMinute: 12),
                FixtureDay(low: 4, high: 13, wmo: 2, precipitationProbability: 20,
                           sunriseHour: 7, sunriseMinute: 8, sunsetHour: 19, sunsetMinute: 9),
                FixtureDay(low: 4, high: 14, wmo: 1, precipitationProbability: 10,
                           sunriseHour: 7, sunriseMinute: 10, sunsetHour: 19, sunsetMinute: 6),
                FixtureDay(low: 5, high: 13, wmo: 2, precipitationProbability: 15,
                           sunriseHour: 7, sunriseMinute: 12, sunsetHour: 19, sunsetMinute: 3),
                FixtureDay(low: 6, high: 12, wmo: 3, precipitationProbability: 30,
                           sunriseHour: 7, sunriseMinute: 14, sunsetHour: 19, sunsetMinute: 0),
                FixtureDay(low: 6, high: 11, wmo: 61, precipitationProbability: 65,
                           sunriseHour: 7, sunriseMinute: 16, sunsetHour: 18, sunsetMinute: 57),
                FixtureDay(low: 5, high: 10, wmo: 61, precipitationProbability: 55,
                           sunriseHour: 7, sunriseMinute: 18, sunsetHour: 18, sunsetMinute: 54),
                FixtureDay(low: 4, high: 10, wmo: 3, precipitationProbability: 25,
                           sunriseHour: 7, sunriseMinute: 20, sunsetHour: 18, sunsetMinute: 51),
            ]
        ),
        fetchedAt: fixtureNow.addingTimeInterval(-5 * 60)
    )
}

extension SavedLocation {
    static let fixtures: [SavedLocation] = [
        SavedLocation(
            id: UUID(uuidString: "6F1B0E2C-1D4A-4C7E-9B3F-0A1D2E3F4A5B")!,
            name: "Lisbon",
            region: "Lisboa",
            country: "Portugal",
            coordinate: Coordinate(latitude: 38.7223, longitude: -9.1393),
            timeZoneIdentifier: "Europe/Lisbon"
        ),
        SavedLocation(
            id: UUID(uuidString: "2C7D9A14-5E6B-4F80-A1C2-B3D4E5F60718")!,
            name: "Oslo",
            region: "Oslo",
            country: "Norway",
            coordinate: Coordinate(latitude: 59.9139, longitude: 10.7522),
            timeZoneIdentifier: "Europe/Oslo"
        ),
        SavedLocation(
            id: UUID(uuidString: "9E3F5B08-4A21-4D6C-8B7E-C0D1E2F3A4B5")!,
            name: "Toronto",
            region: "Ontario",
            country: "Canada",
            coordinate: Coordinate(latitude: 43.6532, longitude: -79.3832),
            timeZoneIdentifier: "America/Toronto"
        ),
    ]
}
#endif
