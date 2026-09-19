import DaybookPlatform
import Foundation

struct SavedLocation: Sendable, Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let region: String?
    let country: String?
    let coordinate: Coordinate
    let timeZoneIdentifier: String
}
