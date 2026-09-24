import DaybookPlatform
import SwiftUI
import WeatherFeature

@main
struct DaybookApp: App {
    private let location = LocationService(now: { Date() })

    var body: some Scene {
        WindowGroup {
            WeatherTab(location: location)
        }
    }
}
