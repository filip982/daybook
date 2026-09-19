import Foundation

enum DaySummary: Sendable, Equatable {
    case precipitation(kind: PrecipitationKind, from: Date, to: Date)
    case gusts(peakKmh: Double, at: Date)
    case warmingUp(toCelsius: Double, at: Date)
    case conditionAndHigh(code: WeatherCode, highCelsius: Double)

    private static let hour: TimeInterval = 3600
    private static let precipitationThreshold = 50
    private static let gustThresholdKmh: Double = 50
    private static let warmingThresholdCelsius: Double = 8

    static func make(from forecast: Forecast, now: Date) -> DaySummary? {
        let window = forecast.hourly.filter {
            $0.time > now.addingTimeInterval(-hour) && $0.time < now.addingTimeInterval(12 * hour)
        }

        if let summary = precipitation(in: window) { return summary }
        if let summary = gusts(in: window) { return summary }
        if let summary = warmingUp(in: window, current: forecast.current) { return summary }

        guard let day = forecast.daily.first else { return nil }
        return .conditionAndHigh(code: day.code, highCelsius: day.highCelsius)
    }

    private static func precipitation(in window: [HourForecast]) -> DaySummary? {
        guard let start = window.firstIndex(where: { $0.precipitationProbability >= precipitationThreshold })
        else { return nil }

        let run = window[start...].prefix { $0.precipitationProbability >= precipitationThreshold }
        guard let first = run.first, let last = run.last else { return nil }

        let kinds = Set(run.compactMap(\.code.precipitationKind))
        let kind: PrecipitationKind = kinds.contains(.thunderstorm) ? .thunderstorm
            : kinds.contains(.snow) ? .snow
            : .rain

        return .precipitation(kind: kind, from: first.time, to: last.time.addingTimeInterval(hour))
    }

    private static func gusts(in window: [HourForecast]) -> DaySummary? {
        guard let peak = window.max(by: { $0.windGustsKmh < $1.windGustsKmh }),
              let earliest = window.first(where: { $0.windGustsKmh == peak.windGustsKmh }),
              earliest.windGustsKmh >= gustThresholdKmh
        else { return nil }

        return .gusts(peakKmh: earliest.windGustsKmh, at: earliest.time)
    }

    private static func warmingUp(in window: [HourForecast], current: CurrentConditions) -> DaySummary? {
        guard let peak = window.max(by: { $0.temperatureCelsius < $1.temperatureCelsius }),
              let earliest = window.first(where: { $0.temperatureCelsius == peak.temperatureCelsius }),
              earliest.temperatureCelsius - current.temperatureCelsius >= warmingThresholdCelsius
        else { return nil }

        return .warmingUp(toCelsius: earliest.temperatureCelsius, at: earliest.time)
    }
}
