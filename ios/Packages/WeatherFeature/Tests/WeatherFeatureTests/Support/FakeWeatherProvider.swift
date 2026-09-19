import DaybookPlatform
import Foundation
@testable import WeatherFeature

actor FakeWeatherProvider: WeatherProvider {
    private var forecastResults: [Result<Forecast, WeatherError>] = []
    private var searchResults: [Result<[SavedLocation], WeatherError>] = []

    private(set) var forecastCalls: [Coordinate] = []
    private(set) var searchCalls: [String] = []

    func enqueueForecast(_ result: Result<Forecast, WeatherError>) {
        forecastResults.append(result)
    }

    func enqueueSearch(_ result: Result<[SavedLocation], WeatherError>) {
        searchResults.append(result)
    }

    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        forecastCalls.append(coordinate)
        guard !forecastResults.isEmpty else { throw .server }
        switch forecastResults.removeFirst() {
        case .success(let forecast): return forecast
        case .failure(let error): throw error
        }
    }

    func search(_ query: String) async throws(WeatherError) -> [SavedLocation] {
        searchCalls.append(query)
        guard !searchResults.isEmpty else { throw .server }
        switch searchResults.removeFirst() {
        case .success(let locations): return locations
        case .failure(let error): throw error
        }
    }
}
