#if DEBUG
import DaybookPlatform

struct FixtureProvider: WeatherProvider {
    init() {}

    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        let toronto = SavedLocation.fixtures.first { $0.name == "Toronto" }!
        return coordinate.rounded() == toronto.coordinate.rounded() ? .fixtureToronto : .fixtureVienna
    }

    func search(_ query: String) async throws(WeatherError) -> [SavedLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return SavedLocation.fixtures.filter {
            $0.name.range(of: trimmed, options: [.caseInsensitive, .anchored]) != nil
        }
    }
}
#endif
