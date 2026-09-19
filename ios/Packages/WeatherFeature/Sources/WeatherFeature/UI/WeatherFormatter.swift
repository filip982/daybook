import Foundation

struct WeatherFormatter: Sendable {
    let locale: Locale
    let timeZone: TimeZone

    private let calendar: Calendar

    init(locale: Locale, timeZone: TimeZone) {
        self.locale = locale
        self.timeZone = timeZone

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        self.calendar = calendar
    }

    func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: displayTemperatureUnit)
            .roundedAwayFromNegativeZero
            .formatted(
                .measurement(
                    width: .narrow,
                    usage: .asProvided,
                    hidesScaleName: true,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                )
                .locale(locale)
            )
    }

    func spokenTemperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: displayTemperatureUnit)
            .roundedAwayFromNegativeZero
            .formatted(
                .measurement(
                    width: .wide,
                    usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                )
                .locale(locale)
            )
    }

    func hourLabel(_ time: Date, now: Date) -> String {
        guard !calendar.isDate(time, equalTo: now, toGranularity: .hour) else { return "Now" }
        return time.formatted(dateStyle.hour(hourSymbol))
    }

    func dayLabel(_ date: Date, now: Date) -> String {
        guard !calendar.isDate(date, inSameDayAs: now) else { return "Today" }
        return date.formatted(dateStyle.weekday(.abbreviated))
    }

    func spokenDayName(_ date: Date, now: Date) -> String {
        guard !calendar.isDate(date, inSameDayAs: now) else { return "Today" }
        return date.formatted(dateStyle.weekday(.wide))
    }

    func percent(_ value: Int) -> String {
        "\(value.formatted(.number.locale(locale)))%"
    }

    func clock(_ time: Date) -> String {
        time.formatted(dateStyle.hour(hourSymbol).minute(.twoDigits))
    }

    func gusts(_ kmh: Double) -> String {
        Measurement(value: kmh, unit: UnitSpeed.kilometersPerHour)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .wind,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                )
                .locale(locale)
            )
    }

    func conditionName(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: "Clear"
        case .mostlyClear: "Mostly clear"
        case .partlyCloudy: "Partly cloudy"
        case .overcast: "Overcast"
        case .fog: "Fog"
        case .drizzle: "Drizzle"
        case .freezingDrizzle: "Freezing drizzle"
        case .rain: "Rain"
        case .freezingRain: "Freezing rain"
        case .snow: "Snow"
        case .snowGrains: "Snow grains"
        case .rainShowers: "Rain showers"
        case .snowShowers: "Snow showers"
        case .thunderstorm: "Thunderstorm"
        case .thunderstormWithHail: "Thunderstorm with hail"
        case .unknown: "Unknown"
        }
    }

    func summary(_ summary: DaySummary) -> String {
        switch summary {
        case let .precipitation(kind, from, to):
            "\(precipitationName(kind)) likely \(clock(from))\u{2013}\(clock(to))"
        case let .gusts(peakKmh, at):
            "Windy around \(clock(at)), gusts up to \(gusts(peakKmh))"
        case let .warmingUp(toCelsius, at):
            "Warming up to \(temperature(toCelsius)) by \(clock(at))"
        case let .conditionAndHigh(code, highCelsius):
            "\(conditionName(code.condition)), high \(temperature(highCelsius))"
        }
    }

    func spokenDay(_ day: DayForecast, now: Date) -> String {
        let condition = spokenCondition(day.code)
        let chance = day.precipitationProbability >= 20
            ? "\(condition), \(day.precipitationProbability) percent chance."
            : "\(condition)."

        return """
            \(spokenDayName(day.date, now: now)). \(chance) \
            Low \(spokenTemperature(day.lowCelsius)), high \(spokenTemperature(day.highCelsius)).
            """
    }

    func updatedAgo(_ fetchedAt: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .abbreviated

        return "Updated \(formatter.localizedString(for: fetchedAt, relativeTo: now))"
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
    }

    private var displayTemperatureUnit: UnitTemperature {
        UnitTemperature(forLocale: locale, usage: .weather)
    }

    private var hourSymbol: Date.FormatStyle.Symbol.Hour {
        switch locale.hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour: .twoDigits(amPM: .omitted)
        default: .defaultDigits(amPM: .abbreviated)
        }
    }

    private func precipitationName(_ kind: PrecipitationKind) -> String {
        switch kind {
        case .rain: "Rain"
        case .snow: "Snow"
        case .thunderstorm: "Thunderstorms"
        }
    }

    private func spokenCondition(_ code: WeatherCode) -> String {
        guard let intensity = code.intensity else { return conditionName(code.condition) }
        return "\(intensityName(intensity)) \(conditionName(code.condition).lowercased())"
    }

    private func intensityName(_ intensity: PrecipitationIntensity) -> String {
        switch intensity {
        case .light: "Light"
        case .moderate: "Moderate"
        case .heavy: "Heavy"
        }
    }
}

private extension Measurement where UnitType == UnitTemperature {
    var roundedAwayFromNegativeZero: Measurement<UnitTemperature> {
        value.rounded() == 0 ? Measurement(value: 0, unit: unit) : self
    }
}
