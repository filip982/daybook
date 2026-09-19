import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

@Suite struct SavedLocationsFileTests {
    @Test func missingFileLoadsAsEmptyThenSaveThenLoadRoundTrips() async throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("saved-locations.json")
        let store = SavedLocationsFile(fileURL: fileURL)

        let empty = await store.load()
        #expect(empty == [])

        await store.save(SavedLocation.fixtures)
        let loaded = await store.load()

        #expect(loaded == SavedLocation.fixtures)
    }

    @Test func aFreshInstanceOnTheSameURLLoadsWhatAnEarlierOneSaved() async throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("saved-locations.json")
        let first = SavedLocationsFile(fileURL: fileURL)
        await first.save(SavedLocation.fixtures)

        let second = SavedLocationsFile(fileURL: fileURL)
        let loaded = await second.load()

        #expect(loaded == SavedLocation.fixtures)
    }

    @Test func garbageBytesLoadAsEmptyAndAreLeftInPlaceUntilTheNextSave() async throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("saved-locations.json")
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)
        let store = SavedLocationsFile(fileURL: fileURL)

        let loaded = await store.load()

        #expect(loaded == [])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        await store.save(SavedLocation.fixtures)
        let reloaded = await store.load()

        #expect(reloaded == SavedLocation.fixtures)
    }

    @Test func savingAnEmptyListThenLoadingReturnsEmpty() async throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("saved-locations.json")
        let store = SavedLocationsFile(fileURL: fileURL)

        await store.save([])
        let loaded = await store.load()

        #expect(loaded == [])
    }
}
