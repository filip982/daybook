import Testing
@testable import DaybookPlatform

actor FakeLocationFixSource: LocationFixSource {
    private static let maximumYields = 10_000

    private let authorizationStatus: LocationAuthorization
    private var fixResults: [Result<Coordinate, LocationError>] = []
    private var placeNames: [Coordinate: String] = [:]
    private var isHoldingNextFix = false
    private var heldFix: CheckedContinuation<Void, Never>?

    private(set) var fixCalls = 0
    private(set) var geocodeCalls: [Coordinate] = []

    init(authorization: LocationAuthorization) {
        authorizationStatus = authorization
    }

    func enqueueFix(_ result: Result<Coordinate, LocationError>) {
        fixResults.append(result)
    }

    func setPlaceName(_ name: String?, for coordinate: Coordinate) {
        placeNames[coordinate] = name
    }

    func holdNextFix() {
        isHoldingNextFix = true
    }

    func releaseFix() {
        heldFix?.resume()
        heldFix = nil
    }

    func waitUntilFixBegan() async {
        for _ in 0..<Self.maximumYields {
            if fixCalls > 0 { return }
            await Task.yield()
        }
        Issue.record("no fix began within \(Self.maximumYields) yields")
    }

    func authorization() async -> LocationAuthorization {
        authorizationStatus
    }

    func fix() async throws(LocationError) -> Coordinate {
        fixCalls += 1
        if isHoldingNextFix {
            isHoldingNextFix = false
            await withCheckedContinuation { heldFix = $0 }
        }
        guard !fixResults.isEmpty else { throw .unavailable }
        return try fixResults.removeFirst().get()
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        geocodeCalls.append(coordinate)
        return placeNames[coordinate]
    }
}
