import DaybookPlatform
import Foundation

enum OpenMeteoSearchMapping {
    static func locations(from data: Data) throws(WeatherError) -> [SavedLocation] {
        let response: SearchResponse
        do {
            response = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw .decoding
        }
        return (response.results ?? []).compactMap(\.toSavedLocation)
    }
}

private struct SearchResponse: Decodable {
    struct Result: Decodable {
        let id: Int64
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
        let timezone: String?

        var toSavedLocation: SavedLocation? {
            guard let timezone, TimeZone(identifier: timezone) != nil else { return nil }
            guard let identifier = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llx", id)) else {
                return nil
            }
            return SavedLocation(
                id: identifier,
                name: name,
                region: admin1,
                country: country,
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                timeZoneIdentifier: timezone
            )
        }
    }

    let results: [Result]?
}
