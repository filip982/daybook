import DaybookPlatform
import SwiftUI

struct DayRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var dayColumnWidth: CGFloat = 54
    @ScaledMetric(relativeTo: .body) private var symbolColumnWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var temperatureColumnWidth: CGFloat = 38

    let day: DayForecast
    let span: TemperatureSpan
    let isToday: Bool
    let currentCelsius: Double?
    let formatter: WeatherFormatter
    let now: Date

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                compact
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayRowLabel(day, formatter: formatter, now: now))
        .accessibilityIdentifier("weather.dayRow")
    }

    private var compact: some View {
        HStack(spacing: theme.spacing.small) {
            Text(formatter.dayLabel(day.date, now: now))
                .font(.body.weight(.medium))
                .frame(width: dayColumnWidth, alignment: .leading)

            symbolWithChance
                .frame(width: symbolColumnWidth)

            Text(formatter.temperature(day.lowCelsius))
                .font(.body)
                .frame(width: temperatureColumnWidth, alignment: .trailing)

            bar

            Text(formatter.temperature(day.highCelsius))
                .font(.body.weight(.semibold))
                .frame(width: temperatureColumnWidth, alignment: .trailing)
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(spacing: theme.spacing.small) {
                symbol
                Text(formatter.spokenDayName(day.date, now: now))
                    .font(.title3.weight(.semibold))
            }

            Text(conditionLine)
                .font(.body)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.small) {
                    lowLabel
                    Spacer(minLength: theme.spacing.small)
                    highLabel
                }
                VStack(alignment: .leading, spacing: theme.spacing.small / 2) {
                    lowLabel
                    highLabel
                }
            }
            .font(.body)

            bar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lowLabel: some View {
        Text("Low \(formatter.temperature(day.lowCelsius))").fixedSize()
    }

    private var highLabel: some View {
        Text("High \(formatter.temperature(day.highCelsius))").fixedSize()
    }

    private var conditionLine: String {
        let name = formatter.conditionName(day.code.condition)
        guard day.precipitationProbability >= 20 else { return name }
        return "\(name), \(formatter.percent(day.precipitationProbability)) chance"
    }

    private var symbol: some View {
        Image(systemName: day.code.symbolName(isDay: true))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: symbolSize))
            .accessibilityHidden(true)
    }

    private var symbolWithChance: some View {
        VStack(spacing: 1) {
            symbol
            if day.precipitationProbability >= 20 {
                Text(formatter.percent(day.precipitationProbability))
                    .font(.caption2.weight(.medium))
            }
        }
    }

    private var bar: some View {
        TemperatureRangeBar(
            span: span,
            low: day.lowCelsius,
            high: day.highCelsius,
            currentCelsius: isToday ? currentCelsius : nil
        )
    }
}
