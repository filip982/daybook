import Foundation
import Testing
@testable import WeatherFeature

actor DelayedFirstWritePersistence: SavedLocationsPersistence {
    private static let maximumYields = 10_000

    private var callsBegun = 0
    private(set) var recordedLists: [[SavedLocation]] = []

    var lastRecordedList: [SavedLocation] { recordedLists.last ?? [] }

    func waitUntilFirstSaveBegan() async {
        for _ in 0..<Self.maximumYields {
            if callsBegun > 0 { return }
            await Task.yield()
        }
        Issue.record("no save began within \(Self.maximumYields) yields")
    }

    func load() async -> [SavedLocation] { [] }

    func save(_ locations: [SavedLocation]) async {
        callsBegun += 1
        if callsBegun == 1 {
            try? await Task.sleep(for: .milliseconds(200))
        }
        recordedLists.append(locations)
    }
}
