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
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityChartDescriptor(
                    TemperatureRangeDescriptor(days: days, span: span, formatter: formatter, now: now)
                )

                ForEach(days, id: \.date) { day in
                    Divider().overlay(theme.cardStroke)
                    DayRow(
                        day: day,
                        span: span,
                        isToday: day.date == days.first?.date,
                        currentCelsius: forecast.current.temperatureCelsius,
                        formatter: formatter,
                        now: now
                    )
                    .padding(.vertical, theme.spacing.small / 2)
                }
            }
        }
    }

    private var days: [DayForecast] { Array(forecast.daily.prefix(10)) }

    private var span: TemperatureSpan { TemperatureSpan(days: days) }
}
