import DaybookPlatform
import SwiftUI

struct WeatherHeader: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .caption) private var locationIconSize: CGFloat = 11
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize: CGFloat = 84

    let forecast: Forecast
    let placeName: String
    let isOffline: Bool
    let isCurrentLocation: Bool
    let formatter: WeatherFormatter
    let now: Date

    var body: some View {
        VStack(spacing: theme.spacing.small / 2) {
            if isCurrentLocation {
                Label {
                    Text("MY LOCATION")
                } icon: {
                    Image(systemName: "location.fill")
                        .font(.system(size: locationIconSize))
                }
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
            }

            Text(placeName)
                .font(.largeTitle)
                .accessibilityAddTraits(.isHeader)

            Text(formatter.temperature(forecast.current.temperatureCelsius))
                .font(.system(size: temperatureSize, weight: .thin))

            Text(formatter.conditionName(forecast.current.code.condition))
                .font(.title3)

            if let today = forecast.daily.first {
                Text("H:\(formatter.temperature(today.highCelsius))  L:\(formatter.temperature(today.lowCelsius))")
                    .font(.headline)
            }

            if let staleLine {
                Label(staleLine, systemImage: "wifi.slash")
                    .font(.footnote)
                    .padding(.top, theme.spacing.small / 2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("weather.header")
    }

    private var staleLine: String? {
        guard isOffline || forecast.isStale(now: now) else { return nil }
        return "Offline · \(formatter.updatedAgo(forecast.fetchedAt, now: now))"
    }
}
