import DaybookPlatform
import SwiftUI

public struct WeatherTab: View {
    private let location: any LocationProviding

    public init(location: any LocationProviding) {
        self.location = location
    }

    public var body: some View {
        #if DEBUG
        WeatherView(
            state: .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false),
            now: Forecast.fixtureNow,
            locale: .autoupdatingCurrent
        )
        #else
        ContentUnavailableView(
            "Weather",
            systemImage: "cloud.sun",
            description: Text("The forecast arrives in the next build step.")
        )
        #endif
    }
}
