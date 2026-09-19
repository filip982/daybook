import Foundation

func dayRowLabel(_ day: DayForecast, formatter: WeatherFormatter, now: Date) -> String {
    formatter.spokenDay(day, now: now)
}

func hourCellLabel(_ hour: HourForecast, formatter: WeatherFormatter, now: Date) -> String {
    let label = formatter.hourLabel(hour.time, now: now)
    let condition = formatter.conditionName(hour.code.condition).lowercased()
    return "\(label), \(condition), \(formatter.spokenTemperature(hour.temperatureCelsius))"
}
