import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

actor FakeWeatherStore: WeatherStore {
    private static let maximumWait = Duration.seconds(10)

    private var cached: [Coordinate: Forecast]
    private var saved: [SavedLocation]
    private var refreshResults: [Result<Forecast, WeatherError>] = []
    private var searchResults: [Result<[SavedLocation], WeatherError>] = []
    private var holdsNextRefresh = false
    private var heldRefresh: CheckedContinuation<Void, Never>?

    private(set) var refreshCalls: [Coordinate] = []
    private(set) var cachedCalls: [Coordinate] = []
    private(set) var searchCalls: [String] = []
    private(set) var reorderCalls: [[SavedLocation.ID]] = []

    init(cached: [Coordinate: Forecast], saved: [SavedLocation]) {
        self.cached = Dictionary(uniqueKeysWithValues: cached.map { ($0.key.rounded(), $0.value) })
        self.saved = saved
    }

    func enqueueRefresh(_ result: Result<Forecast, WeatherError>) {
        refreshResults.append(result)
    }

    func enqueueSearch(_ result: Result<[SavedLocation], WeatherError>) {
        searchResults.append(result)
    }

    func holdNextRefresh() {
        holdsNextRefresh = true
    }

    func releaseRefresh() {
        guard let heldRefresh else {
            holdsNextRefresh = false
            return
        }
        heldRefresh.resume()
        self.heldRefresh = nil
    }

    // Parallel snapshot tests keep the main actor busy, so a fixed yield count can run out first.
    func waitUntilRefreshBegan() async {
        let deadline = ContinuousClock.now + Self.maximumWait
        while ContinuousClock.now < deadline {
            if heldRefresh != nil { return }
            await Task.yield()
        }
        Issue.record("no held refresh began within \(Self.maximumWait)")
    }

    func cachedForecast(for coordinate: Coordinate) async -> Forecast? {
        cachedCalls.append(coordinate)
        return cached[coordinate.rounded()]
    }

    func refreshForecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        refreshCalls.append(coordinate)
        if holdsNextRefresh {
            holdsNextRefresh = false
            await withCheckedContinuation { heldRefresh = $0 }
        }
        guard !refreshResults.isEmpty else { throw .server }
        switch refreshResults.removeFirst() {
        case .success(let forecast):
            cached[coordinate.rounded()] = forecast
            return forecast
        case .failure(let error):
            throw error
        }
    }

    func searchPlaces(_ query: String) async throws(WeatherError) -> [SavedLocation] {
        searchCalls.append(query)
        guard !searchResults.isEmpty else { throw .server }
        switch searchResults.removeFirst() {
        case .success(let locations): return locations
        case .failure(let error): throw error
        }
    }

    func savedLocations() async -> [SavedLocation] {
        saved
    }

    func save(_ location: SavedLocation) async {
        guard !saved.contains(where: { $0.id == location.id }) else { return }
        saved.append(location)
    }

    func remove(id: SavedLocation.ID) async {
        saved.removeAll { $0.id == id }
    }

    func reorder(_ ids: [SavedLocation.ID]) async {
        reorderCalls.append(ids)
        var remaining = saved
        var ordered: [SavedLocation] = []
        for id in ids {
            guard let index = remaining.firstIndex(where: { $0.id == id }) else { continue }
            ordered.append(remaining.remove(at: index))
        }
        saved = ordered + remaining
    }
}
