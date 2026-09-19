#if DEBUG
import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

private struct StoreHarness {
    let directory: TemporaryDirectory
    let provider: FakeWeatherProvider
    let fileURL: URL

    init() throws {
        directory = try TemporaryDirectory()
        provider = FakeWeatherProvider()
        fileURL = directory.url.appendingPathComponent("saved-locations.json")
    }

    func makeStore() -> LiveWeatherStore {
        LiveWeatherStore(
            provider: provider,
            cache: FileForecastCache(directory: directory.url.appendingPathComponent("Forecasts")),
            savedLocations: SavedLocationsFile(fileURL: fileURL)
        )
    }
}

private func location(_ index: Int) -> SavedLocation {
    SavedLocation(
        id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!,
        name: "Place \(index)",
        region: nil,
        country: nil,
        coordinate: Coordinate(latitude: Double(index), longitude: Double(index)),
        timeZoneIdentifier: "UTC"
    )
}

@Suite struct LiveWeatherStoreForecastTests {
    @Test func refreshReturnsTheProvidersForecastAndTheNextCachedReadHitsTheCache() async throws {
        let harness = try StoreHarness()
        await harness.provider.enqueueForecast(.success(.fixtureVienna))
        let store = harness.makeStore()
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)

        let refreshed = try await store.refreshForecast(for: coordinate)
        let cached = await store.cachedForecast(for: coordinate)

        #expect(refreshed == .fixtureVienna)
        #expect(cached == .fixtureVienna)
        let calls = await harness.provider.forecastCalls
        #expect(calls.count == 1)
    }

    @Test func theProviderReceivesTheRoundedCoordinateAndNearbyPointsShareOneCacheEntry() async throws {
        let harness = try StoreHarness()
        await harness.provider.enqueueForecast(.success(.fixtureVienna))
        let store = harness.makeStore()

        _ = try await store.refreshForecast(for: Coordinate(latitude: 48.20849, longitude: 16.37208))
        let nearby = await store.cachedForecast(for: Coordinate(latitude: 48.20851, longitude: 16.37209))

        let calls = await harness.provider.forecastCalls
        #expect(calls == [Coordinate(latitude: 48.21, longitude: 16.37)])
        #expect(nearby == .fixtureVienna)
    }

    @Test func refreshFailureThrowsAndLeavesTheEarlierCachedForecastInPlace() async throws {
        let harness = try StoreHarness()
        await harness.provider.enqueueForecast(.success(.fixtureVienna))
        await harness.provider.enqueueForecast(.failure(.offline))
        let store = harness.makeStore()
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)

        _ = try await store.refreshForecast(for: coordinate)

        await #expect(throws: WeatherError.offline) {
            try await store.refreshForecast(for: coordinate)
        }

        let cached = await store.cachedForecast(for: coordinate)
        #expect(cached == .fixtureVienna)
    }

    @Test func refreshFailureOnAnEmptyCacheThrowsAndLeavesTheCacheEmpty() async throws {
        let harness = try StoreHarness()
        await harness.provider.enqueueForecast(.failure(.server))
        let store = harness.makeStore()
        let coordinate = Coordinate(latitude: 43.6532, longitude: -79.3832)

        await #expect(throws: WeatherError.server) {
            try await store.refreshForecast(for: coordinate)
        }

        let cached = await store.cachedForecast(for: coordinate)
        #expect(cached == nil)
    }

    @Test func cachedForecastNeverCallsTheProvider() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()

        let cached = await store.cachedForecast(for: Coordinate(latitude: 48.21, longitude: 16.37))

        #expect(cached == nil)
        let calls = await harness.provider.forecastCalls
        #expect(calls.isEmpty)
    }

    @Test func searchForwardsTheQueryAndReturnsTheProvidersResults() async throws {
        let harness = try StoreHarness()
        await harness.provider.enqueueSearch(.success(SavedLocation.fixtures))
        let store = harness.makeStore()

        let results = try await store.searchPlaces("Lisbon")

        #expect(results == SavedLocation.fixtures)
        let calls = await harness.provider.searchCalls
        #expect(calls == ["Lisbon"])
    }

    @Test func searchFailurePropagatesTheWeatherError() async throws {
        let harness = try StoreHarness()
        await harness.provider.enqueueSearch(.failure(.notFound))
        let store = harness.makeStore()

        await #expect(throws: WeatherError.notFound) {
            try await store.searchPlaces("Nowhere")
        }
    }
}

@Suite struct LiveWeatherStoreSavedLocationsTests {
    @Test func savedLocationsStartEmpty() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()

        let locations = await store.savedLocations()

        #expect(locations == [])
    }

    @Test func saveAppendsInOrderAndSurvivesANewStore() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()

        for fixture in SavedLocation.fixtures {
            await store.save(fixture)
        }

        #expect(await store.savedLocations() == SavedLocation.fixtures)
        #expect(await harness.makeStore().savedLocations() == SavedLocation.fixtures)
    }

    @Test func savingTheSameIdTwiceKeepsOneEntry() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()

        await store.save(SavedLocation.fixtures[0])
        await store.save(SavedLocation.fixtures[0])
        await store.save(SavedLocation.fixtures[1])

        #expect(await store.savedLocations() == [SavedLocation.fixtures[0], SavedLocation.fixtures[1]])
        #expect(await harness.makeStore().savedLocations() == [SavedLocation.fixtures[0], SavedLocation.fixtures[1]])
    }

    @Test func removeDeletesTheMatchingLocationAndSurvivesANewStore() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()
        for fixture in SavedLocation.fixtures {
            await store.save(fixture)
        }

        await store.remove(id: SavedLocation.fixtures[1].id)

        let expected = [SavedLocation.fixtures[0], SavedLocation.fixtures[2]]
        #expect(await store.savedLocations() == expected)
        #expect(await harness.makeStore().savedLocations() == expected)
    }

    @Test func removeOfAnUnknownIdIsANoOp() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()
        for fixture in SavedLocation.fixtures {
            await store.save(fixture)
        }

        await store.remove(id: UUID())

        #expect(await store.savedLocations() == SavedLocation.fixtures)
        #expect(await harness.makeStore().savedLocations() == SavedLocation.fixtures)
    }

    @Test func reorderWithTheFullListAppliesTheGivenOrder() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()
        for fixture in SavedLocation.fixtures {
            await store.save(fixture)
        }

        await store.reorder([
            SavedLocation.fixtures[2].id,
            SavedLocation.fixtures[0].id,
            SavedLocation.fixtures[1].id,
        ])

        let expected = [SavedLocation.fixtures[2], SavedLocation.fixtures[0], SavedLocation.fixtures[1]]
        #expect(await store.savedLocations() == expected)
        #expect(await harness.makeStore().savedLocations() == expected)
    }

    @Test func reorderWithAPartialListLeavesUnmentionedLocationsAtTheEndInTheirOrder() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()
        for fixture in SavedLocation.fixtures {
            await store.save(fixture)
        }

        await store.reorder([SavedLocation.fixtures[2].id])

        let expected = [SavedLocation.fixtures[2], SavedLocation.fixtures[0], SavedLocation.fixtures[1]]
        #expect(await store.savedLocations() == expected)
        #expect(await harness.makeStore().savedLocations() == expected)
    }

    @Test func reorderIgnoresIdsThatAreNotInTheList() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()
        for fixture in SavedLocation.fixtures {
            await store.save(fixture)
        }

        await store.reorder([UUID(), SavedLocation.fixtures[1].id, UUID(), SavedLocation.fixtures[0].id])

        let expected = [SavedLocation.fixtures[1], SavedLocation.fixtures[0], SavedLocation.fixtures[2]]
        #expect(await store.savedLocations() == expected)
        #expect(await harness.makeStore().savedLocations() == expected)
    }

    @Test func twentyConcurrentSavesAllSurviveInMemoryAndOnDisk() async throws {
        let harness = try StoreHarness()
        let store = harness.makeStore()
        let expected = (0..<20).map(location(_:))

        await withTaskGroup(of: Void.self) { group in
            for candidate in expected {
                group.addTask { await store.save(candidate) }
            }
        }

        let inMemory = await store.savedLocations()
        #expect(Set(inMemory.map(\.id)) == Set(expected.map(\.id)))

        let reloaded = await harness.makeStore().savedLocations()
        #expect(Set(reloaded.map(\.id)) == Set(expected.map(\.id)))
    }
}
#endif
