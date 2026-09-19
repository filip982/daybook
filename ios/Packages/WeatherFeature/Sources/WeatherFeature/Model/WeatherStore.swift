import DaybookPlatform

protocol WeatherStore: Sendable {
    func cachedForecast(for coordinate: Coordinate) async -> Forecast?
    func refreshForecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast
    func searchPlaces(_ query: String) async throws(WeatherError) -> [SavedLocation]
    func savedLocations() async -> [SavedLocation]
    func save(_ location: SavedLocation) async
    func remove(id: SavedLocation.ID) async
    func reorder(_ ids: [SavedLocation.ID]) async
}
