import Foundation
import Testing
@testable import WeatherFeature

@Suite struct StubNetworkTests {
    @Test func concurrentSessionsEachSeeTheirOwnResponder() async throws {
        let first = StubNetwork.session { _ in StubResponse(body: Data("first".utf8)) }
        let second = StubNetwork.session { _ in StubResponse(body: Data("second".utf8)) }

        async let a = first.data(from: URL(string: "https://example.com/a")!)
        async let b = second.data(from: URL(string: "https://example.com/b")!)
        let (firstData, _) = try await a
        let (secondData, _) = try await b

        #expect(String(decoding: firstData, as: UTF8.self) == "first")
        #expect(String(decoding: secondData, as: UTF8.self) == "second")
    }

    @Test func statusCodeReachesTheCaller() async throws {
        let session = StubNetwork.session { _ in StubResponse(statusCode: 400, body: Data("{}".utf8)) }

        let (_, response) = try await session.data(from: URL(string: "https://example.com")!)

        #expect((response as? HTTPURLResponse)?.statusCode == 400)
    }

    @Test func responderErrorSurfacesAsURLError() async {
        let session = StubNetwork.session { _ in StubResponse(error: .notConnectedToInternet) }

        do {
            _ = try await session.data(from: URL(string: "https://example.com")!)
            Issue.record("expected a URLError")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("expected a URLError, got \(error)")
        }
    }
}

@Suite struct StubFixtureTests {
    static let names = [
        "forecast-vienna",
        "forecast-honolulu",
        "search-lisbon",
        "search-no-match",
        "error-bad-latitude",
    ]

    @Test(arguments: names) func fixtureLoadsAndParsesAsJSON(name: String) throws {
        let data = try StubNetwork.fixture(name)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object != nil)
    }

    @Test func viennaHasTimeZoneTwentyFourHoursAndTenDays() throws {
        let object = try JSONSerialization.jsonObject(with: StubNetwork.fixture("forecast-vienna")) as? [String: Any]
        let root = try #require(object)

        let hourlyTimes = try #require((root["hourly"] as? [String: Any])?["time"] as? [Int])
        let dailyTimes = try #require((root["daily"] as? [String: Any])?["time"] as? [Int])

        #expect(root["timezone"] as? String == "Europe/Vienna")
        #expect(hourlyTimes.count == 24)
        #expect(dailyTimes.count == 10)
    }

    @Test func noMatchSearchHasNoResultsKey() throws {
        let object = try JSONSerialization.jsonObject(with: StubNetwork.fixture("search-no-match")) as? [String: Any]
        #expect(try #require(object)["results"] == nil)
    }
}
