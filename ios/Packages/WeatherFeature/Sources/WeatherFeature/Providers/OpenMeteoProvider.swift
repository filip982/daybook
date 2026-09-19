import DaybookPlatform
import Foundation

struct OpenMeteoProvider: WeatherProvider {
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .dataNotAllowed,
        .internationalRoamingOff,
    ]

    private let session: URLSession
    private let now: @Sendable () -> Date

    init(session: URLSession = .shared, now: @escaping @Sendable () -> Date = { Date() }) {
        self.session = session
        self.now = now
    }

    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast {
        guard let url = Self.forecastURL(for: coordinate) else { throw .server }
        let data = try await load(URLRequest(url: url))
        return try OpenMeteoForecastMapping.forecast(from: data, fetchedAt: now())
    }

    func search(_: String) async throws(WeatherError) -> [SavedLocation] {
        throw .server
    }

    private func load(_ request: URLRequest) async throws(WeatherError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            // `throws(WeatherError)` cannot carry a CancellationError, so cancellation surfaces as `.offline`.
            if error.code == .cancelled { throw .offline }
            throw Self.offlineCodes.contains(error.code) ? .offline : .server
        } catch {
            throw .server
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw .server
        }
        return data
    }

    private static func forecastURL(for coordinate: Coordinate) -> URL? {
        let rounded = coordinate.rounded()
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: decimal(rounded.latitude)),
            URLQueryItem(name: "longitude", value: decimal(rounded.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,wind_gusts_10m"
            ),
            URLQueryItem(
                name: "hourly",
                value: "temperature_2m,weather_code,precipitation_probability,wind_gusts_10m,is_day"
            ),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "forecast_hours", value: "24"),
        ]
        return components.url
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
