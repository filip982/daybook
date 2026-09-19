import DaybookPlatform
import Foundation

protocol ForecastCache: Sendable {
    func forecast(for coordinate: Coordinate) async -> Forecast?
    func store(_ forecast: Forecast, for coordinate: Coordinate) async
}

actor FileForecastCache: ForecastCache {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func defaultDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("Forecasts")
    }

    func forecast(for coordinate: Coordinate) async -> Forecast? {
        let fileURL = fileURL(for: coordinate)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        guard let forecast = try? JSONDecoder().decode(Forecast.self, from: data) else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return forecast
    }

    func store(_ forecast: Forecast, for coordinate: Coordinate) async {
        guard let data = try? JSONEncoder().encode(forecast) else { return }
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            return
        }
        try? data.write(to: fileURL(for: coordinate), options: .atomic)
    }

    private func fileURL(for coordinate: Coordinate) -> URL {
        let rounded = coordinate.rounded()
        let name = "forecast_\(Self.decimal(rounded.latitude))_\(Self.decimal(rounded.longitude)).json"
        return directory.appendingPathComponent(name)
    }

    private static func decimal(_ value: Double) -> String {
        let normalized = value == 0 ? 0 : value
        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), normalized)
    }
}
