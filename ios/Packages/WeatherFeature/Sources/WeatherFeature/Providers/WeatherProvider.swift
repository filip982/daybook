import DaybookPlatform

protocol WeatherProvider: Sendable {
    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast
    func search(_ query: String) async throws(WeatherError) -> [SavedLocation]
}
