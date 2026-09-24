import DaybookPlatform
import SwiftUI

struct WeatherView: View {
    @Environment(\.theme) private var theme

    private let state: WeatherScreenState
    private let now: Date
    private let locale: Locale
    private let isCurrentLocation: Bool
    private let onAllowLocation: () -> Void
    private let onRetry: () -> Void
    private let onOpenSettings: () -> Void
    private let onRefresh: () async -> Void
    private let onShowLocations: () -> Void

    init(
        state: WeatherScreenState,
        now: Date,
        locale: Locale,
        isCurrentLocation: Bool = true,
        onAllowLocation: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onRefresh: @escaping () async -> Void = {},
        onShowLocations: @escaping () -> Void = {}
    ) {
        self.state = state
        self.now = now
        self.locale = locale
        self.isCurrentLocation = isCurrentLocation
        self.onAllowLocation = onAllowLocation
        self.onRetry = onRetry
        self.onOpenSettings = onOpenSettings
        self.onRefresh = onRefresh
        self.onShowLocations = onShowLocations
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.skyGradient(currentSky), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            content
        }
        .foregroundStyle(.white)
        .tint(.white)
        .environment(\.locale, locale)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case let .loaded(forecast, placeName, isOffline):
            withLocationsButton(loaded(forecast, placeName: placeName, isOffline: isOffline))
        case .locationNotAsked:
            LocationNotAskedView(onAllowLocation: onAllowLocation)
        case .locationDenied:
            withLocationsButton(LocationDeniedView(onOpenSettings: onOpenSettings))
        case .loading:
            WeatherLoadingView()
        case let .failed(error):
            withLocationsButton(WeatherFailedView(error: error, onRetry: onRetry))
        }
    }

    private func withLocationsButton(_ content: some View) -> some View {
        content.safeAreaInset(edge: .top, alignment: .trailing, spacing: 0) {
            Button(action: onShowLocations) {
                Label("Locations", systemImage: "list.bullet")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("weather.locationsButton")
            .padding(.trailing, theme.spacing.small)
        }
    }

    private func loaded(_ forecast: Forecast, placeName: String, isOffline: Bool) -> some View {
        let formatter = WeatherFormatter(locale: locale, timeZone: forecast.timeZone)

        return ScrollView {
            VStack(spacing: theme.spacing.medium) {
                WeatherHeader(
                    forecast: forecast,
                    placeName: placeName,
                    isOffline: isOffline,
                    isCurrentLocation: isCurrentLocation,
                    formatter: formatter,
                    now: now
                )
                .padding(.top, theme.spacing.large)

                HourlyCard(forecast: forecast, formatter: formatter, now: now)
                DailyCard(forecast: forecast, formatter: formatter, now: now)

                attribution
            }
            .padding(.horizontal, theme.spacing.medium)
            .padding(.bottom, theme.spacing.large)
        }
        .refreshable { await onRefresh() }
    }

    private var attribution: some View {
        Text("Weather data by Open-Meteo.com · CC BY 4.0")
            .font(.caption2)
            .padding(.top, theme.spacing.small)
    }

    private var currentSky: Theme.Sky {
        switch state {
        case let .loaded(forecast, _, _): sky(for: forecast)
        case .locationNotAsked, .locationDenied, .loading, .failed: .clearDay
        }
    }
}
