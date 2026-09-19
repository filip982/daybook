import Foundation
@testable import WeatherFeature

actor DelayedFirstWritePersistence: SavedLocationsPersistence {
    private var callsBegun = 0
    private(set) var recordedLists: [[SavedLocation]] = []

    var lastRecordedList: [SavedLocation] { recordedLists.last ?? [] }

    func waitUntilFirstSaveBegan() async {
        while callsBegun == 0 {
            await Task.yield()
        }
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
