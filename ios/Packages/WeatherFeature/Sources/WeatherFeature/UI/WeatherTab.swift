import DaybookPlatform
import SwiftUI

public struct WeatherTab: View {
    private let location: any LocationProviding

    public init(location: any LocationProviding) {
        self.location = location
    }

    public var body: some View {
        ContentUnavailableView(
            "Weather",
            systemImage: "cloud.sun",
            description: Text("The forecast arrives in the next build step.")
        )
    }
}
