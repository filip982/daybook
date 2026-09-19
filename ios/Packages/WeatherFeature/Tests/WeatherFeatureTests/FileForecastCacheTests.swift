import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

@Suite struct FileForecastCacheTests {
    @Test func storeThenReadReturnsAnEqualForecast() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)

        await cache.store(.fixtureVienna, for: coordinate)
        let read = await cache.forecast(for: coordinate)

        #expect(read == .fixtureVienna)
    }

    @Test func readingBeforeAnyWriteReturnsNilAndCreatesNothing() async throws {
        let directory = try TemporaryDirectory()
        let cacheDirectory = directory.url.appendingPathComponent("Forecasts")
        let cache = FileForecastCache(directory: cacheDirectory)

        let read = await cache.forecast(for: Coordinate(latitude: 48.20849, longitude: 16.37208))

        #expect(read == nil)
        #expect(!FileManager.default.fileExists(atPath: cacheDirectory.path))
    }

    @Test func twoCoordinatesThatRoundTheSameShareOneFileAndDifferingOnesDoNot() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let a = Coordinate(latitude: 48.2084, longitude: 16.3721)
        let b = Coordinate(latitude: 48.20851, longitude: 16.37209)
        let c = Coordinate(latitude: 43.6532, longitude: -79.3832)

        await cache.store(.fixtureVienna, for: a)
        let readB = await cache.forecast(for: b)
        let readC = await cache.forecast(for: c)

        #expect(readB == .fixtureVienna)
        #expect(readC == nil)

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.url.path)
        #expect(files == ["forecast_48.21_16.37.json"])
    }

    @Test func fileNameForSydneyCoordinateIsExact() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let coordinate = Coordinate(latitude: -33.86785, longitude: 151.20732)

        await cache.store(.fixtureVienna, for: coordinate)

        let expected = directory.url.appendingPathComponent("forecast_-33.87_151.21.json")
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test func negativeZeroCoordinateRoundsToPlainZeroInFileName() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let coordinate = Coordinate(latitude: -0.001, longitude: 0.001)

        await cache.store(.fixtureVienna, for: coordinate)

        let expected = directory.url.appendingPathComponent("forecast_0.00_0.00.json")
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test func garbageBytesAreAMissAndTheFileIsDeleted() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)
        let fileURL = directory.url.appendingPathComponent("forecast_48.21_16.37.json")
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)

        let read = await cache.forecast(for: coordinate)

        #expect(read == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func truncatedValidJSONIsAMissAndTheFileIsDeleted() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)
        let fileURL = directory.url.appendingPathComponent("forecast_48.21_16.37.json")
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        let full = try JSONEncoder().encode(Forecast.fixtureVienna)
        try full.prefix(full.count / 2).write(to: fileURL)

        let read = await cache.forecast(for: coordinate)

        #expect(read == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func storingTwiceKeepsOnlyTheNewerForecast() async throws {
        let directory = try TemporaryDirectory()
        let cache = FileForecastCache(directory: directory.url)
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)

        await cache.store(.fixtureVienna, for: coordinate)
        await cache.store(.fixtureToronto, for: coordinate)
        let read = await cache.forecast(for: coordinate)

        #expect(read == .fixtureToronto)
    }

    @Test func directoryThatCannotBeCreatedFailsStoreSilentlyAndReadsNil() async throws {
        let directory = try TemporaryDirectory()
        let regularFile = directory.url.appendingPathComponent("blocking-file")
        try Data().write(to: regularFile)
        let cacheDirectory = regularFile.appendingPathComponent("sub")
        let cache = FileForecastCache(directory: cacheDirectory)
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)

        await cache.store(.fixtureVienna, for: coordinate)
        let read = await cache.forecast(for: coordinate)

        #expect(read == nil)
    }

    @Test func aFreshCacheInstancePointedAtTheSameDirectoryReadsWhatAnEarlierInstanceWrote() async throws {
        let directory = try TemporaryDirectory()
        let coordinate = Coordinate(latitude: 48.20849, longitude: 16.37208)
        let first = FileForecastCache(directory: directory.url)
        await first.store(.fixtureVienna, for: coordinate)

        let second = FileForecastCache(directory: directory.url)
        let read = await second.forecast(for: coordinate)

        #expect(read == .fixtureVienna)
    }
}
