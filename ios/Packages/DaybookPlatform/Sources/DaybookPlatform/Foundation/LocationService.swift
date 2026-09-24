import Foundation
import os

protocol LocationFixSource: Sendable {
    func authorization() async -> LocationAuthorization
    func fix() async throws(LocationError) -> Coordinate
    func placeName(for coordinate: Coordinate) async -> String?
}

public actor LocationService: LocationProviding {
    static let reuseInterval: TimeInterval = 60

    private static let logger = Logger(subsystem: "com.replicantstudio.daybook", category: "location")

    private let source: any LocationFixSource
    private let now: @Sendable () -> Date
    private var lastFix: (place: LocatedPlace, fixedAt: Date)?
    private var inFlight: Task<Result<LocatedPlace, LocationError>, Never>?

    public init(now: @escaping @Sendable () -> Date) {
        self.init(source: CoreLocationFixSource(), now: now)
    }

    init(source: any LocationFixSource, now: @escaping @Sendable () -> Date) {
        self.source = source
        self.now = now
    }

    public func authorization() async -> LocationAuthorization {
        await source.authorization()
    }

    public func current() async throws(LocationError) -> LocatedPlace {
        if let lastFix, now().timeIntervalSince(lastFix.fixedAt) < Self.reuseInterval {
            return lastFix.place
        }
        let fetch = inFlight ?? startFetch()
        return try await fetch.value.get()
    }

    private func startFetch() -> Task<Result<LocatedPlace, LocationError>, Never> {
        let fetch = Task { await self.fetch() }
        inFlight = fetch
        return fetch
    }

    private func fetch() async -> Result<LocatedPlace, LocationError> {
        defer { inFlight = nil }
        do {
            let coordinate = try await source.fix()
            let fixedAt = now()
            let place = LocatedPlace(coordinate: coordinate, name: await source.placeName(for: coordinate))
            lastFix = (place, fixedAt)
            return .success(place)
        } catch {
            Self.logger.error("Location fix failed: \(String(describing: error), privacy: .public)")
            return .failure(error)
        }
    }
}
