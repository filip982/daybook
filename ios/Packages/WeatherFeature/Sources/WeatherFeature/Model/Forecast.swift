import Foundation

struct CurrentConditions: Sendable, Codable, Equatable {
    let temperatureCelsius: Double
    let apparentTemperatureCelsius: Double
    let code: WeatherCode
    let isDay: Bool
    let windSpeedKmh: Double
    let windGustsKmh: Double
}

struct HourForecast: Sendable, Codable, Equatable {
    let time: Date
    let temperatureCelsius: Double
    let code: WeatherCode
    let isDay: Bool
    let precipitationProbability: Int
    let windGustsKmh: Double
}

struct DayForecast: Sendable, Codable, Equatable {
    let date: Date
    let code: WeatherCode
    let highCelsius: Double
    let lowCelsius: Double
    let precipitationProbability: Int
    let sunrise: Date
    let sunset: Date
}

struct Forecast: Sendable, Codable, Equatable {
    static let timeToLive: TimeInterval = 30 * 60

    let timeZone: TimeZone
    let current: CurrentConditions
    let hourly: [HourForecast]
    let daily: [DayForecast]
    let fetchedAt: Date

    func isStale(now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) >= Self.timeToLive
    }
}
