import Foundation

extension LiveWeatherStore {
    static let fixtureLaunchArgument = "-daybookFixtures"

    static func clock(arguments: [String] = ProcessInfo.processInfo.arguments) -> @Sendable () -> Date {
        #if DEBUG
        if arguments.contains(fixtureLaunchArgument) {
            return { Forecast.fixtureNow }
        }
        #endif
        return { Date() }
    }

    static func live(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        cacheDirectory: URL = FileForecastCache.defaultDirectory(),
        savedLocationsURL: URL = SavedLocationsFile.defaultFileURL(),
        now: (@Sendable () -> Date)? = nil
    ) -> LiveWeatherStore {
        let cache = FileForecastCache(directory: cacheDirectory)
        let savedLocations = SavedLocationsFile(fileURL: savedLocationsURL)
        let clock = now ?? Self.clock(arguments: arguments)

        #if DEBUG
        if arguments.contains(fixtureLaunchArgument) {
            return LiveWeatherStore(
                provider: FixtureProvider(now: clock),
                cache: cache,
                savedLocations: savedLocations
            )
        }
        #endif

        let provider = OpenMeteoProvider(
            session: .shared,
            languageCode: languageCode(for: .autoupdatingCurrent),
            now: clock
        )
        return LiveWeatherStore(provider: provider, cache: cache, savedLocations: savedLocations)
    }

    static func languageCode(for locale: Locale) -> String {
        guard let identifier = locale.language.languageCode?.identifier else { return "en" }
        return String(identifier.prefix(2))
    }
}
