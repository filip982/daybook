import DaybookPlatform
import Foundation

actor LiveWeatherStore: WeatherStore {
    private let provider: any WeatherProvider
    private let cache: any ForecastCache
    private let savedLocationsStore: any SavedLocationsPersistence
    private var locations: [SavedLocation]?

    init(provider: any WeatherProvider, cache: any ForecastCache, savedLocations: any SavedLocationsPersistence) {
        self.provider = provider
        self.cache = cache
        self.savedLocationsStore = savedLocations
    }

    func cachedForecast(for coordinate: Coordinate) async -> Forecast? {
        await cache.forecast(for: coordinate.rounded())
    }

    func refreshForecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        let rounded = coordinate.rounded()
        let forecast = try await provider.forecast(for: rounded)
        await cache.store(forecast, for: rounded)
        return forecast
    }

    func searchPlaces(_ query: String) async throws(WeatherError) -> [SavedLocation] {
        try await provider.search(query)
    }

    func savedLocations() async -> [SavedLocation] {
        await loadedLocations()
    }

    func save(_ location: SavedLocation) async {
        var current = await loadedLocations()
        guard !current.contains(where: { $0.id == location.id }) else { return }
        current.append(location)
        await persist(current)
    }

    func remove(id: SavedLocation.ID) async {
        var current = await loadedLocations()
        guard current.contains(where: { $0.id == id }) else { return }
        current.removeAll { $0.id == id }
        await persist(current)
    }

    func reorder(_ ids: [SavedLocation.ID]) async {
        let current = await loadedLocations()
        var remaining = current
        var ordered: [SavedLocation] = []
        for id in ids {
            guard let index = remaining.firstIndex(where: { $0.id == id }) else { continue }
            ordered.append(remaining.remove(at: index))
        }
        await persist(ordered + remaining)
    }

    private func loadedLocations() async -> [SavedLocation] {
        if let locations { return locations }
        let loaded = await savedLocationsStore.load()
        if let locations { return locations }
        locations = loaded
        return loaded
    }

    private func persist(_ updated: [SavedLocation]) async {
        locations = updated
        await savedLocationsStore.save(updated)
    }
}
