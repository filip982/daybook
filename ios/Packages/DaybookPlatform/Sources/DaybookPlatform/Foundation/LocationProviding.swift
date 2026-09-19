public struct LocatedPlace: Sendable, Equatable {
    public let coordinate: Coordinate
    public let name: String?

    public init(coordinate: Coordinate, name: String?) {
        self.coordinate = coordinate
        self.name = name
    }
}

public enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

public enum LocationError: Error, Sendable, Equatable {
    case denied
    case unavailable
}

public protocol LocationProviding: Sendable {
    func authorization() async -> LocationAuthorization
    func current() async throws(LocationError) -> LocatedPlace
}
