import DaybookPlatform
import SwiftUI

struct HourlyCard: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .title3) private var symbolSize: CGFloat = 22

    let forecast: Forecast
    let formatter: WeatherFormatter
    let now: Date

    var body: some View {
        WeatherCard {
            VStack(alignment: .leading, spacing: theme.spacing.medium) {
                if let summary = DaySummary.make(from: forecast, now: now) {
                    Text(formatter.summary(summary))
                        .font(.subheadline)
                    Divider().overlay(theme.cardStroke)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: theme.spacing.large) {
                        ForEach(hours, id: \.time) { hour in
                            cell(hour)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var hours: [HourForecast] {
        Array(forecast.hourly.filter { $0.time >= startOfCurrentHour }.prefix(12))
    }

    private var startOfCurrentHour: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = forecast.timeZone
        return calendar.dateInterval(of: .hour, for: now)?.start ?? now
    }

    private func cell(_ hour: HourForecast) -> some View {
        VStack(spacing: theme.spacing.small) {
            Text(formatter.hourLabel(hour.time, now: now))
                .font(.footnote.weight(.medium))
            Image(systemName: hour.code.symbolName(isDay: hour.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: symbolSize))
                .accessibilityHidden(true)
            Text(formatter.temperature(hour.temperatureCelsius))
                .font(.body.weight(.medium))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hourCellLabel(hour, formatter: formatter, now: now))
    }
}
