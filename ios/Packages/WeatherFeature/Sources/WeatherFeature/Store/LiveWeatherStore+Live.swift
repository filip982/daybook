import Foundation

extension LiveWeatherStore {
    static let fixtureLaunchArgument = "-daybookFixtures"

    static func live(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        cacheDirectory: URL = FileForecastCache.defaultDirectory(),
        savedLocationsURL: URL = SavedLocationsFile.defaultFileURL(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> LiveWeatherStore {
        let cache = FileForecastCache(directory: cacheDirectory)
        let savedLocations = SavedLocationsFile(fileURL: savedLocationsURL)

        #if DEBUG
        if arguments.contains(fixtureLaunchArgument) {
            return LiveWeatherStore(provider: FixtureProvider(), cache: cache, savedLocations: savedLocations)
        }
        #endif

        let provider = OpenMeteoProvider(
            session: .shared,
            languageCode: languageCode(for: .autoupdatingCurrent),
            now: now
        )
        return LiveWeatherStore(provider: provider, cache: cache, savedLocations: savedLocations)
    }

    static func languageCode(for locale: Locale) -> String {
        guard let identifier = locale.language.languageCode?.identifier else { return "en" }
        return String(identifier.prefix(2))
    }
}
