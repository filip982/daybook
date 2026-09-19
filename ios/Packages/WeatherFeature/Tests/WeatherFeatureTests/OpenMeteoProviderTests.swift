import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

private struct FixtureJSON {
    let root: [String: Any]

    init(_ name: String) throws {
        let data = try StubNetwork.fixture(name)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        root = try #require(object)
    }

    var timeZone: TimeZone {
        get throws {
            let identifier = try #require(root["timezone"] as? String)
            return try #require(TimeZone(identifier: identifier))
        }
    }

    func group(_ key: String) throws -> [String: Any] {
        try #require(root[key] as? [String: Any])
    }

    func doubles(_ key: String, _ field: String) throws -> [Double] {
        let values = try group(key)[field] as? [Double]
        return try #require(values)
    }

    func ints(_ key: String, _ field: String) throws -> [Int] {
        let values = try group(key)[field] as? [Int]
        return try #require(values)
    }

}

private func replacing(_ name: String, _ transform: (inout [String: Any]) -> Void) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: try StubNetwork.fixture(name)) as? [String: Any]
    var root = try #require(object)
    transform(&root)
    return try JSONSerialization.data(withJSONObject: root)
}

private let fixedNow = Date(timeIntervalSince1970: 1_758_300_000)

private func provider(
    _ name: String,
    statusCode: Int = 200,
    now: Date = fixedNow,
    capturing captured: (@Sendable (URLRequest) -> Void)? = nil
) throws -> OpenMeteoProvider {
    let body = try StubNetwork.fixture(name)
    return OpenMeteoProvider(
        session: StubNetwork.session { request in
            captured?(request)
            return StubResponse(statusCode: statusCode, body: body)
        },
        now: { now }
    )
}

private func provider(body: Data, statusCode: Int = 200, now: Date = fixedNow) -> OpenMeteoProvider {
    OpenMeteoProvider(
        session: StubNetwork.session { _ in StubResponse(statusCode: statusCode, body: body) },
        now: { now }
    )
}

private func failingProvider(_ code: URLError.Code) -> OpenMeteoProvider {
    OpenMeteoProvider(
        session: StubNetwork.session { _ in StubResponse(error: code) },
        now: { fixedNow }
    )
}

private let vienna = Coordinate(latitude: 48.20849, longitude: 16.37208)
private let honoluluCoordinate = Coordinate(latitude: 21.31, longitude: -157.86)

@Suite struct OpenMeteoRequestTests {
    @Test func requestMatchesTheRecordedFixtureURL() async throws {
        let box = URLBox()
        let subject = try provider("forecast-vienna") { box.store($0.url) }

        _ = try await subject.forecast(for: vienna)

        let url = try #require(box.value)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try #require(components.queryItems)
        let items = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

        #expect(components.scheme == "https")
        #expect(components.host == "api.open-meteo.com")
        #expect(components.path == "/v1/forecast")
        #expect(items["latitude"] == "48.21")
        #expect(items["longitude"] == "16.37")
        #expect(items["current"] == "temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,wind_gusts_10m")
        #expect(items["hourly"] == "temperature_2m,weather_code,precipitation_probability,wind_gusts_10m,is_day")
        #expect(items["daily"] == "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset")
        #expect(items["timezone"] == "auto")
        #expect(items["timeformat"] == "unixtime")
        #expect(items["forecast_days"] == "10")
        #expect(items["forecast_hours"] == "24")
        #expect(items.count == 9)
    }
}

private final class URLBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URL?

    func store(_ url: URL?) {
        lock.withLock { stored = url }
    }

    var value: URL? { lock.withLock { stored } }
}

@Suite struct OpenMeteoForecastMappingTests {
    @Test func viennaFixtureMapsEveryField() async throws {
        let fixture = try FixtureJSON("forecast-vienna")
        let subject = try provider("forecast-vienna")

        let forecast = try await subject.forecast(for: vienna)

        let current = try fixture.group("current")
        #expect(forecast.timeZone.identifier == "Europe/Vienna")
        #expect(forecast.hourly.count == 24)
        #expect(forecast.daily.count == 10)
        #expect(forecast.fetchedAt == fixedNow)
        #expect(forecast.current.temperatureCelsius == current["temperature_2m"] as? Double)
        #expect(forecast.current.apparentTemperatureCelsius == current["apparent_temperature"] as? Double)
        #expect(forecast.current.code.wmo == current["weather_code"] as? Int)
        #expect(forecast.current.isDay == (current["is_day"] as? Int == 1))
        #expect(forecast.current.windSpeedKmh == current["wind_speed_10m"] as? Double)
        #expect(forecast.current.windGustsKmh == current["wind_gusts_10m"] as? Double)

        #expect(forecast.hourly.map(\.temperatureCelsius) == (try fixture.doubles("hourly", "temperature_2m")))
        #expect(forecast.hourly.map(\.code.wmo) == (try fixture.ints("hourly", "weather_code")))
        #expect(forecast.hourly.map(\.precipitationProbability) == (try fixture.ints("hourly", "precipitation_probability")))
        #expect(forecast.hourly.map(\.windGustsKmh) == (try fixture.doubles("hourly", "wind_gusts_10m")))
        #expect(forecast.hourly.map(\.isDay) == (try fixture.ints("hourly", "is_day")).map { $0 == 1 })

        #expect(forecast.daily.map(\.code.wmo) == (try fixture.ints("daily", "weather_code")))
        #expect(forecast.daily.map(\.highCelsius) == (try fixture.doubles("daily", "temperature_2m_max")))
        #expect(forecast.daily.map(\.lowCelsius) == (try fixture.doubles("daily", "temperature_2m_min")))
        #expect(forecast.daily.map(\.precipitationProbability) == (try fixture.ints("daily", "precipitation_probability_max")))

        let hourStamps = try fixture.ints("hourly", "time")
        let dayStamps = try fixture.ints("daily", "time")
        #expect(forecast.hourly.map(\.time.timeIntervalSince1970) == hourStamps.map(Double.init))
        #expect(forecast.daily.map(\.date.timeIntervalSince1970) == dayStamps.map(Double.init))

        let hours = forecast.hourly.map(\.time)
        for (earlier, later) in zip(hours, hours.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) == 3600)
        }
    }

    @Test func sunriseAndSunsetAreTheInstantsFromTheFixture() async throws {
        let fixture = try FixtureJSON("forecast-vienna")
        let subject = try provider("forecast-vienna")

        let forecast = try await subject.forecast(for: vienna)

        let sunrises = try fixture.ints("daily", "sunrise")
        let sunsets = try fixture.ints("daily", "sunset")

        #expect(forecast.daily.map(\.sunrise.timeIntervalSince1970) == sunrises.map(Double.init))
        #expect(forecast.daily.map(\.sunset.timeIntervalSince1970) == sunsets.map(Double.init))
    }

    @Test func viennaDaysStartAtLocalMidnight() async throws {
        let fixture = try FixtureJSON("forecast-vienna")
        let subject = try provider("forecast-vienna")

        let forecast = try await subject.forecast(for: vienna)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try fixture.timeZone

        for day in forecast.daily {
            #expect(calendar.startOfDay(for: day.date) == day.date)
        }
    }
}

@Suite struct OpenMeteoTimeZoneTests {
    @Test func honoluluDaysStartAtLocalMidnightNotViennaMidnight() async throws {
        let subject = try provider("forecast-honolulu")

        let forecast = try await subject.forecast(for: honoluluCoordinate)

        #expect(forecast.timeZone.identifier == "Pacific/Honolulu")

        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = try #require(TimeZone(identifier: "Pacific/Honolulu"))
        var viennaCalendar = Calendar(identifier: .gregorian)
        viennaCalendar.timeZone = try #require(TimeZone(identifier: "Europe/Vienna"))

        let first = forecast.daily[0].date
        #expect(honolulu.startOfDay(for: first) == first)
        #expect(viennaCalendar.startOfDay(for: first) != first)

        for day in forecast.daily {
            #expect(honolulu.startOfDay(for: day.date) == day.date)
        }
    }

    @Test func honoluluHoursSitOnTheHourInTheResponseZone() async throws {
        let subject = try provider("forecast-honolulu")

        let forecast = try await subject.forecast(for: honoluluCoordinate)

        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = try #require(TimeZone(identifier: "Pacific/Honolulu"))

        for hour in forecast.hourly {
            let parts = honolulu.dateComponents([.minute, .second], from: hour.time)
            #expect(parts.minute == 0)
            #expect(parts.second == 0)
        }
    }

    @Test func unknownZoneIdentifierFallsBackToTheUTCOffset() async throws {
        let fixture = try FixtureJSON("forecast-vienna")
        let offset = try #require(fixture.root["utc_offset_seconds"] as? Int)
        let body = try replacing("forecast-vienna") { root in
            root["timezone"] = "Mars/Olympus_Mons"
        }

        let forecast = try await provider(body: body).forecast(for: vienna)

        #expect(forecast.timeZone.secondsFromGMT() == offset)
    }

    @Test func fallBackDayKeepsTwentyFourDistinctHoursAndRepeatsTheLocalHour() async throws {
        // 2026-10-24T22:00:00Z = 00:00 local on 2026-10-25, the Vienna fall-back day.
        let startOfFallBackDay = 1_792_879_200
        let stamps = (0..<24).map { startOfFallBackDay + $0 * 3600 }
        let body = try replacing("forecast-vienna") { root in
            var hourly = root["hourly"] as? [String: Any] ?? [:]
            hourly["time"] = stamps
            hourly["temperature_2m"] = Array(repeating: 10.0, count: 24)
            hourly["weather_code"] = Array(repeating: 0, count: 24)
            hourly["precipitation_probability"] = Array(repeating: 0, count: 24)
            hourly["wind_gusts_10m"] = Array(repeating: 5.0, count: 24)
            hourly["is_day"] = Array(repeating: 1, count: 24)
            root["hourly"] = hourly
        }

        let forecast = try await provider(body: body).forecast(for: vienna)

        let times = forecast.hourly.map(\.time)
        #expect(times.count == 24)
        #expect(Set(times).count == 24)
        for (earlier, later) in zip(times, times.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) == 3600)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Vienna"))
        let hours = times.map { calendar.component(.hour, from: $0) }

        #expect(Array(hours.prefix(6)) == [0, 1, 2, 2, 3, 4])
    }
}

@Suite struct OpenMeteoNullHandlingTests {
    @Test func nullPrecipitationProbabilitiesBecomeZero() async throws {
        let body = try replacing("forecast-vienna") { root in
            var hourly = root["hourly"] as? [String: Any] ?? [:]
            let count = (hourly["time"] as? [Int])?.count ?? 0
            hourly["precipitation_probability"] = Array(repeating: NSNull(), count: count)
            root["hourly"] = hourly
        }

        let forecast = try await provider(body: body).forecast(for: vienna)

        #expect(forecast.hourly.count == 24)
        #expect(forecast.hourly.allSatisfy { $0.precipitationProbability == 0 })
    }

    @Test func nullDailyProbabilityAndGustsBecomeZero() async throws {
        let body = try replacing("forecast-vienna") { root in
            var daily = root["daily"] as? [String: Any] ?? [:]
            let dayCount = (daily["time"] as? [Int])?.count ?? 0
            daily["precipitation_probability_max"] = Array(repeating: NSNull(), count: dayCount)
            root["daily"] = daily

            var hourly = root["hourly"] as? [String: Any] ?? [:]
            let hourCount = (hourly["time"] as? [Int])?.count ?? 0
            hourly["wind_gusts_10m"] = Array(repeating: NSNull(), count: hourCount)
            root["hourly"] = hourly
        }

        let forecast = try await provider(body: body).forecast(for: vienna)

        #expect(forecast.daily.count == 10)
        #expect(forecast.hourly.count == 24)
        #expect(forecast.daily.allSatisfy { $0.precipitationProbability == 0 })
        #expect(forecast.hourly.allSatisfy { $0.windGustsKmh == 0 })
    }
}

@Suite struct OpenMeteoErrorTests {
    @Test func mismatchedHourlyArrayLengthsFailDecoding() async throws {
        let body = try replacing("forecast-vienna") { root in
            var hourly = root["hourly"] as? [String: Any] ?? [:]
            hourly["temperature_2m"] = (hourly["temperature_2m"] as? [Double]).map { Array($0.dropLast()) }
            root["hourly"] = hourly
        }

        await #expect(throws: WeatherError.decoding) {
            try await provider(body: body).forecast(for: vienna)
        }
    }

    @Test func mismatchedDailyArrayLengthsFailDecoding() async throws {
        let body = try replacing("forecast-vienna") { root in
            var daily = root["daily"] as? [String: Any] ?? [:]
            daily["sunset"] = (daily["sunset"] as? [Int]).map { Array($0.dropLast()) }
            root["daily"] = daily
        }

        await #expect(throws: WeatherError.decoding) {
            try await provider(body: body).forecast(for: vienna)
        }
    }

    @Test func truncatedJSONFailsDecoding() async throws {
        let full = try StubNetwork.fixture("forecast-vienna")
        let body = full.prefix(full.count / 2)

        await #expect(throws: WeatherError.decoding) {
            try await provider(body: Data(body)).forecast(for: vienna)
        }
    }

    @Test func badRequestBodyIsAServerError() async throws {
        let subject = try provider("error-bad-latitude", statusCode: 400)

        await #expect(throws: WeatherError.server) {
            try await subject.forecast(for: vienna)
        }
    }

    @Test func serverFailureIsAServerError() async throws {
        let subject = try provider("forecast-vienna", statusCode: 500)

        await #expect(throws: WeatherError.server) {
            try await subject.forecast(for: vienna)
        }
    }

    @Test(arguments: [
        URLError.Code.notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .dataNotAllowed,
        .internationalRoamingOff,
    ])
    func transportFailuresWithoutConnectivityAreOffline(code: URLError.Code) async {
        await #expect(throws: WeatherError.offline) {
            try await failingProvider(code).forecast(for: vienna)
        }
    }

    @Test func otherTransportFailuresAreServerErrors() async {
        await #expect(throws: WeatherError.server) {
            try await failingProvider(.badServerResponse).forecast(for: vienna)
        }
    }

    @Test func cancellationSurfacesAsOffline() async {
        await #expect(throws: WeatherError.offline) {
            try await failingProvider(.cancelled).forecast(for: vienna)
        }
    }
}

private func searchProvider(
    _ name: String,
    statusCode: Int = 200,
    languageCode: String = "en",
    capturing captured: (@Sendable (URLRequest) -> Void)? = nil
) throws -> OpenMeteoProvider {
    let body = try StubNetwork.fixture(name)
    return OpenMeteoProvider(
        session: StubNetwork.session { request in
            captured?(request)
            return StubResponse(statusCode: statusCode, body: body)
        },
        languageCode: languageCode,
        now: { fixedNow }
    )
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.withLock { count += 1 }
    }

    var value: Int { lock.withLock { count } }
}

private func queryItems(of url: URL) throws -> [String: String?] {
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let items = try #require(components.queryItems)
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
}

@Suite struct OpenMeteoSearchRequestTests {
    @Test func requestUsesTheGeocodingEndpointWithATrimmedName() async throws {
        let box = URLBox()
        let subject = try searchProvider("search-lisbon") { box.store($0.url) }

        _ = try await subject.search("  Lisbon ")

        let url = try #require(box.value)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try queryItems(of: url)

        #expect(components.scheme == "https")
        #expect(components.host == "geocoding-api.open-meteo.com")
        #expect(components.path == "/v1/search")
        #expect(items["name"] == "Lisbon")
        #expect(items["count"] == "10")
        #expect(items["language"] == "en")
        #expect(items["format"] == "json")
        #expect(items.count == 4)
    }

    @Test func languageCodeComesFromTheInitializer() async throws {
        let box = URLBox()
        let subject = try searchProvider("search-lisbon", languageCode: "pt") { box.store($0.url) }

        _ = try await subject.search("Lisbon")

        let items = try queryItems(of: try #require(box.value))
        #expect(items["language"] == "pt")
    }

    @Test func namesWithSpacesAndNonASCIICharactersArePercentEncoded() async throws {
        let box = URLBox()
        let subject = try searchProvider("search-lisbon") { box.store($0.url) }

        _ = try await subject.search(" São Paulo ")

        let url = try #require(box.value)
        #expect(url.absoluteString.contains("S%C3%A3o%20Paulo") || url.absoluteString.contains("S%C3%A3o+Paulo"))

        let items = try queryItems(of: url)
        #expect(items["name"] == "São Paulo")
    }

    @Test func aQueryShorterThanTwoCharactersSkipsTheRequest() async throws {
        let counter = CallCounter()
        let body = try StubNetwork.fixture("search-lisbon")
        let subject = OpenMeteoProvider(
            session: StubNetwork.session { _ in
                counter.increment()
                return StubResponse(statusCode: 200, body: body)
            },
            now: { fixedNow }
        )

        #expect(try await subject.search("L").isEmpty)
        #expect(try await subject.search(" a ").isEmpty)
        #expect(try await subject.search("   ").isEmpty)
        #expect(counter.value == 0)
    }
}

@Suite struct OpenMeteoSearchMappingTests {
    @Test func lisbonFixtureMapsTheFirstResult() async throws {
        let subject = try searchProvider("search-lisbon")

        let results = try await subject.search("Lisbon")

        let lisbon = try #require(results.first)
        #expect(lisbon.name == "Lisbon")
        #expect(lisbon.country == "Portugal")
        #expect(lisbon.region == "Lisbon District")
        #expect(lisbon.timeZoneIdentifier == "Europe/Lisbon")
        #expect(lisbon.coordinate == Coordinate(latitude: 38.72509, longitude: -9.1498))
        #expect(lisbon.id == UUID(uuidString: "00000000-0000-0000-0000-0000002297B1"))
        #expect(results.count == 10)
    }

    @Test func mappingTwiceYieldsEqualIdentifiers() async throws {
        let first = try await searchProvider("search-lisbon").search("Lisbon")
        let second = try await searchProvider("search-lisbon").search("Lisbon")

        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test func aResponseWithoutResultsIsAnEmptyArray() async throws {
        let subject = try searchProvider("search-no-match")

        #expect(try await subject.search("Zzzzzzz").isEmpty)
    }

    @Test func resultsWithAMissingOrInvalidTimeZoneAreSkipped() async throws {
        let body = try replacing("search-lisbon") { root in
            var results = root["results"] as? [[String: Any]] ?? []
            results[1].removeValue(forKey: "timezone")
            results[2]["timezone"] = "Mars/Olympus_Mons"
            root["results"] = results
        }

        let results = try await provider(body: body).search("Lisbon")

        #expect(results.count == 8)
        #expect(results.first?.timeZoneIdentifier == "Europe/Lisbon")
        #expect(results.allSatisfy { TimeZone(identifier: $0.timeZoneIdentifier) != nil })

        let skipped = [
            UUID(uuidString: "00000000-0000-0000-0000-0000004EBFF7"),
            UUID(uuidString: "00000000-0000-0000-0000-0000004D3642"),
        ]
        #expect(!results.contains { skipped.contains($0.id) })
    }
}

@Suite struct OpenMeteoSearchErrorTests {
    @Test func transportFailureWithoutConnectivityIsOffline() async {
        await #expect(throws: WeatherError.offline) {
            try await failingProvider(.notConnectedToInternet).search("Lisbon")
        }
    }

    @Test func serverFailureIsAServerError() async throws {
        let subject = try searchProvider("search-lisbon", statusCode: 500)

        await #expect(throws: WeatherError.server) {
            try await subject.search("Lisbon")
        }
    }

    @Test func truncatedJSONFailsDecoding() async throws {
        let full = try StubNetwork.fixture("search-lisbon")
        let body = Data(full.prefix(full.count / 2))

        await #expect(throws: WeatherError.decoding) {
            try await provider(body: body).search("Lisbon")
        }
    }
}

@Suite struct OpenMeteoDaySummaryTests {
    @Test func mappedForecastFeedsDaySummary() async throws {
        let fixture = try FixtureJSON("forecast-vienna")
        let subject = try provider("forecast-vienna")

        let forecast = try await subject.forecast(for: vienna)

        let stamp = try fixture.group("current")["time"] as? Int
        let now = Date(timeIntervalSince1970: Double(try #require(stamp)))

        #expect(DaySummary.make(from: forecast, now: now) != nil)
    }
}
