import DaybookPlatform
import SwiftUI
import Testing
import UIKit
@testable import WeatherFeature

@Suite @MainActor struct WeatherTabTests {
    @Test func publicEntryAcceptsAnyLocationProvider() {
        _ = WeatherTab(location: FakeLocation(authorization: .notDetermined, current: [.failure(.unavailable)]))
    }

    @Test func viewModelEntryHostsWithoutCrashing() {
        let viewModel = WeatherViewModel(
            store: FakeWeatherStore(cached: [:], saved: []),
            location: FakeLocation(authorization: .notDetermined, current: [.failure(.unavailable)]),
            now: TestClock(Date(timeIntervalSince1970: 0)).closure,
            locale: Locale(identifier: "en_AT")
        )
        let controller = UIHostingController(rootView: WeatherTab(viewModel: viewModel))

        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()

        #expect(controller.view != nil)
    }
}
