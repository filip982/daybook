import DaybookPlatform
import SwiftUI

struct DailyCard: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .caption) private var titleIconSize: CGFloat = 12

    let forecast: Forecast
    let formatter: WeatherFormatter
    let now: Date

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Label {
                    Text("10-DAY FORECAST")
                } icon: {
                    Image(systemName: "calendar")
                        .font(.system(size: titleIconSize))
                }
                .font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Divider().overlay(theme.cardStroke)
                    DayRow(
                        day: day,
                        span: span,
                        isToday: index == 0,
                        currentCelsius: forecast.current.temperatureCelsius,
                        formatter: formatter,
                        now: now
                    )
                    .padding(.vertical, theme.spacing.small / 2)
                }
            }
            .accessibilityChartDescriptor(
                TemperatureRangeDescriptor(days: days, span: span, formatter: formatter, now: now)
            )
        }
    }

    private var days: [DayForecast] { Array(forecast.daily.prefix(10)) }

    private var span: TemperatureSpan { TemperatureSpan(days: days) }
}
