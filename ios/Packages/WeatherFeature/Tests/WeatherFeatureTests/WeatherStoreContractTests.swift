import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

private let contractNow = Date(timeIntervalSince1970: 1_758_300_000)
private let viennaCoordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)

private struct ContractHarness {
    let store: any WeatherStore
    let directory: TemporaryDirectory
    let cacheDirectory: URL
    private let now: Date
    private let respond: @Sendable (URLRequest) -> StubResponse

    init(now: Date, respond: @escaping @Sendable (URLRequest) -> StubResponse) throws {
        directory = try TemporaryDirectory()
        cacheDirectory = directory.url.appendingPathComponent("Forecasts")
        self.now = now
        self.respond = respond
        store = Self.makeStore(directory: directory, cacheDirectory: cacheDirectory, now: now, respond: respond)
    }

    func secondStore() -> any WeatherStore {
        Self.makeStore(directory: directory, cacheDirectory: cacheDirectory, now: now, respond: respond)
    }

    func writeCorruptCacheEntry(for coordinate: Coordinate) throws {
        let rounded = coordinate.rounded()
        let name = String(
            format: "forecast_%.2f_%.2f.json",
            locale: Locale(identifier: "en_US_POSIX"),
            rounded.latitude,
            rounded.longitude
        )
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try Data("not a forecast".utf8).write(to: cacheDirectory.appendingPathComponent(name))
    }

    private static func makeStore(
        directory: TemporaryDirectory,
        cacheDirectory: URL,
        now: Date,
        respond: @escaping @Sendable (URLRequest) -> StubResponse
    ) -> any WeatherStore {
        LiveWeatherStore(
            provider: OpenMeteoProvider(session: StubNetwork.session(respond: respond), now: { now }),
            cache: FileForecastCache(directory: cacheDirectory),
            savedLocations: SavedLocationsFile(
                fileURL: directory.url.appendingPathComponent("saved-locations.json")
            )
        )
    }
}

private func makeHarness(
    now: Date = contractNow,
    respond: @escaping @Sendable (URLRequest) -> StubResponse
) throws -> ContractHarness {
    try ContractHarness(now: now, respond: respond)
}

private final class ResponseScript: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: [StubResponse]
    private let fallback: StubResponse

    init(_ responses: [StubResponse], fallback: StubResponse) {
        remaining = responses
        self.fallback = fallback
    }

    func next() -> StubResponse {
        lock.withLock {
            guard !remaining.isEmpty else { return fallback }
            return remaining.removeFirst()
        }
    }
}

private func forecastFixture() throws -> Data {
    try StubNetwork.fixture("forecast-vienna")
}

private func searchFixture() throws -> Data {
    try StubNetwork.fixture("search-lisbon")
}

@Suite struct WeatherStoreContractForecastTests {
    @Test func refreshReturnsAViennaForecastStampedWithNowAndTheCacheReturnsAnEqualValue() async throws {
        let body = try forecastFixture()
        let harness = try makeHarness { _ in StubResponse(statusCode: 200, body: body) }

        let refreshed = try await harness.store.refreshForecast(for: viennaCoordinate)
        let cached = await harness.store.cachedForecast(for: viennaCoordinate)

        #expect(refreshed.timeZone.identifier == "Europe/Vienna")
        #expect(refreshed.fetchedAt == contractNow)
        #expect(!refreshed.hourly.isEmpty)
        #expect(!refreshed.daily.isEmpty)
        #expect(cached == refreshed)
    }

    @Test func offlineAfterASuccessfulRefreshThrowsAndLeavesTheFirstForecastCached() async throws {
        let body = try forecastFixture()
        let script = ResponseScript(
            [StubResponse(statusCode: 200, body: body)],
            fallback: StubResponse(error: .notConnectedToInternet)
        )
        let harness = try makeHarness { _ in script.next() }

        let first = try await harness.store.refreshForecast(for: viennaCoordinate)

        await #expect(throws: WeatherError.offline) {
            try await harness.store.refreshForecast(for: viennaCoordinate)
        }

        let cached = await harness.store.cachedForecast(for: viennaCoordinate)
        #expect(cached == first)
    }

    @Test func offlineWithNothingCachedThrowsAndLeavesTheCacheEmpty() async throws {
        let harness = try makeHarness { _ in StubResponse(error: .notConnectedToInternet) }

        await #expect(throws: WeatherError.offline) {
            try await harness.store.refreshForecast(for: viennaCoordinate)
        }

        #expect(await harness.store.cachedForecast(for: viennaCoordinate) == nil)
    }

    @Test func aServerFailureThrowsServerAndWritesNoCacheEntry() async throws {
        let body = try forecastFixture()
        let harness = try makeHarness { _ in StubResponse(statusCode: 500, body: body) }

        await #expect(throws: WeatherError.server) {
            try await harness.store.refreshForecast(for: viennaCoordinate)
        }

        #expect(await harness.store.cachedForecast(for: viennaCoordinate) == nil)
    }

    @Test func aTruncatedBodyThrowsDecodingAndWritesNoCacheEntry() async throws {
        let full = try forecastFixture()
        let body = Data(full.prefix(full.count / 2))
        let harness = try makeHarness { _ in StubResponse(statusCode: 200, body: body) }

        await #expect(throws: WeatherError.decoding) {
            try await harness.store.refreshForecast(for: viennaCoordinate)
        }

        #expect(await harness.store.cachedForecast(for: viennaCoordinate) == nil)
    }

    @Test func aCorruptCacheEntryReadsAsNilAndARefreshRepairsIt() async throws {
        let body = try forecastFixture()
        let harness = try makeHarness { _ in StubResponse(statusCode: 200, body: body) }
        try harness.writeCorruptCacheEntry(for: viennaCoordinate)

        #expect(await harness.store.cachedForecast(for: viennaCoordinate) == nil)

        let refreshed = try await harness.store.refreshForecast(for: viennaCoordinate)

        #expect(await harness.store.cachedForecast(for: viennaCoordinate) == refreshed)
    }

    @Test func aForecastGoesStaleThirtyMinutesAfterItWasFetched() async throws {
        let body = try forecastFixture()
        let harness = try makeHarness { _ in StubResponse(statusCode: 200, body: body) }

        let forecast = try await harness.store.refreshForecast(for: viennaCoordinate)

        #expect(!forecast.isStale(now: contractNow.addingTimeInterval(29 * 60)))
        #expect(forecast.isStale(now: contractNow.addingTimeInterval(31 * 60)))
    }
}

@Suite struct WeatherStoreContractSearchTests {
    @Test func searchReturnsLisbonFirstAndSavingItSurvivesInASecondStoreOnTheSameDirectory() async throws {
        let search = try searchFixture()
        let harness = try makeHarness { request in
            guard request.url?.host == "geocoding-api.open-meteo.com" else {
                return StubResponse(statusCode: 500)
            }
            return StubResponse(statusCode: 200, body: search)
        }

        let results = try await harness.store.searchPlaces("Lisbon")
        let lisbon = try #require(results.first)
        #expect(lisbon.name == "Lisbon")
        #expect(lisbon.timeZoneIdentifier == "Europe/Lisbon")

        await harness.store.save(lisbon)

        let reloaded = await harness.secondStore().savedLocations()
        #expect(reloaded == [lisbon])
        #expect(reloaded.first?.id == lisbon.id)
    }
}
