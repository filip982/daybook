import DaybookPlatform
import SwiftUI
import WeatherFeature

@main
struct DaybookApp: App {
    var body: some Scene {
        WindowGroup {
            WeatherTab(location: PlaceholderLocation())
        }
    }
}

private struct PlaceholderLocation: LocationProviding {
    func authorization() async -> LocationAuthorization { .notDetermined }
    func current() async throws(LocationError) -> LocatedPlace { throw .unavailable }
}
