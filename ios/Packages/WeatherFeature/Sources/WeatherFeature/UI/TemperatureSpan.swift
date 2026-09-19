import Foundation

struct TemperatureSpan: Equatable {
    let minimum: Double
    let maximum: Double

    init(minimum: Double, maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }

    init(days: [DayForecast]) {
        self.init(
            minimum: days.map(\.lowCelsius).min() ?? 0,
            maximum: days.map(\.highCelsius).max() ?? 0
        )
    }

    func fractions(low: Double, high: Double) -> (start: Double, end: Double) {
        guard maximum > minimum else { return (0, 1) }
        return (fraction(of: low), fraction(of: high))
    }

    func fraction(of celsius: Double) -> Double {
        guard maximum > minimum else { return 0 }
        return min(max((celsius - minimum) / (maximum - minimum), 0), 1)
    }
}
