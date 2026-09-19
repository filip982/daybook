#if DEBUG
import DaybookPlatform
import Foundation

struct FixtureProvider: WeatherProvider {
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        let fixture = Self.fixture(for: coordinate)
        return Forecast(
            timeZone: fixture.timeZone,
            current: fixture.current,
            hourly: fixture.hourly,
            daily: fixture.daily,
            fetchedAt: now()
        )
    }

    func search(_ query: String) async throws(WeatherError) -> [SavedLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return SavedLocation.fixtures.filter {
            $0.name.range(of: trimmed, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    private static func fixture(for coordinate: Coordinate) -> Forecast {
        let rounded = coordinate.rounded()
        guard let match = SavedLocation.fixtures.first(where: { $0.coordinate.rounded() == rounded })
        else { return .fixtureVienna }

        switch match.timeZoneIdentifier {
        case "Europe/Lisbon": return .fixtureLisbon
        case "Europe/Oslo": return .fixtureOslo
        case "America/Toronto": return .fixtureToronto
        default: return .fixtureVienna
        }
    }
}
#endif
