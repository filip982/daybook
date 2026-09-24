import DaybookPlatform
import SwiftUI
import UIKit

public struct WeatherTab: View {
    @Environment(\.openURL) private var openURL
    @State private var viewModel: WeatherViewModel
    @State private var showsLocations = false

    public init(location: any LocationProviding) {
        let clock = LiveWeatherStore.clock()
        let store = LiveWeatherStore.live(now: clock)
        self.init(viewModel: WeatherViewModel(
            store: store,
            location: LiveWeatherStore.location(fallback: location),
            now: clock,
            locale: .autoupdatingCurrent
        ))
    }

    init(viewModel: WeatherViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        WeatherView(
            state: viewModel.state,
            now: viewModel.currentDate,
            locale: viewModel.locale,
            isCurrentLocation: viewModel.selectedPlace == .current,
            onAllowLocation: { Task { await viewModel.allowLocation() } },
            onRetry: { Task { await viewModel.retry() } },
            onOpenSettings: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            },
            onRefresh: { await viewModel.refresh() },
            onShowLocations: { showsLocations = true }
        )
        .sheet(isPresented: $showsLocations) {
            LocationsView(viewModel: viewModel, onDone: { showsLocations = false })
        }
        .task { await viewModel.start() }
        .onChange(of: viewModel.loadingAnnouncements) {
            AccessibilityNotification.Announcement("Loading forecast").post()
        }
    }
}
