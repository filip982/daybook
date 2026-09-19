# Phase 1, Step 3: Open-Meteo Provider and Geocoding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tested `OpenMeteoProvider` that turns real Open-Meteo forecast and geocoding responses into the app's `Forecast` and `SavedLocation` values, with correct time zones and error mapping, plus a nightly live schema check.

**Architecture:** A new `Providers/` folder inside the single `WeatherFeature` target. `WeatherProvider` is the internal port; `OpenMeteoProvider` implements it on an injected `URLSession`. DTOs are `private` to their file. Nothing under `UI/` may name these types. The provider is not wired into the UI in this step; the store arrives in step 4.

**Tech Stack:** Swift 6, Foundation `URLSession`, Swift Testing, a per-test `URLProtocol` stub, recorded JSON fixtures as test resources, GitHub Actions schedule.

**Spec:** `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`, sections 4 (Providers), 6, 8, 10, 11 and step 3 of section 12.

Signatures, request parameters and test cases below are binding verbatim. Implementers write the bodies.

## Global Constraints

- Every task is exactly one commit on branch `develop`. Never commit to `main`. Never push.
- Commit messages carry no `Co-Authored-By` trailer and no tool attribution.
- iOS 18.0 minimum, Xcode 26.5, Swift 6.3.2, Swift 6 language mode. Simulator: `platform=iOS Simulator,name=iPhone 17,OS=26.5`.
- No new third-party packages.
- `WeatherTab` stays the only `public` type. Provider types are internal; DTOs are `private` or `fileprivate`.
- `make lint` must stay green: nothing under `UI/` names a type declared under `Providers/`.
- Unit tests never touch the network. Each test builds its own `URLSession` with the stub protocol and its own response key. No shared static handler without a per-test key and a lock.
- Coordinates are rounded with `Coordinate.rounded()` before they go into any URL.
- Requests are metric: no `temperature_unit`, `wind_speed_unit` or `precipitation_unit` parameters.
- Never call `Date()` in provider code; `now` is injected as `@Sendable () -> Date`.
- Open-Meteo returns local wall-clock strings WITHOUT an offset (`2026-09-19T16:00`, `2026-09-19`). Parse them in the response's own `timezone` identifier. Never parse them in the device zone or as UTC.
- Tests use Swift Testing. No comments unless the reason would genuinely surprise a reader.

## File Structure

```
ios/Packages/WeatherFeature/Package.swift                                         (test resources)
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/WeatherCode.swift         (intensity moves here)
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherFormatter.swift       (uses the model's intensity)
ios/Packages/WeatherFeature/Sources/WeatherFeature/Providers/WeatherProvider.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Providers/OpenMeteoProvider.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Providers/OpenMeteoForecastMapping.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Providers/OpenMeteoSearchMapping.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Support/StubURLProtocol.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Fixtures/*.json
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/OpenMeteo*Tests.swift
.github/workflows/ios-live.yml, Makefile, README.md
```

---

### Task 1: Precipitation intensity on WeatherCode

Moves the spoken intensity out of the formatter, as the step 2 review asked.

**Produces:**

```swift
enum PrecipitationIntensity: String, Sendable, Codable { case light, moderate, heavy }
extension WeatherCode { var intensity: PrecipitationIntensity? { get } }
```

Mapping: WMO 51, 56, 61, 66, 71, 80, 85 → light · 53, 63, 73, 81 → moderate · 55, 57, 65, 67, 75, 82, 86 → heavy · everything else nil.

- [ ] Parameterized test over all codes above plus 0, 3, 45, 95 (nil).
- [ ] `WeatherFormatter.spokenDay` uses `code.intensity` and no longer holds its own WMO table. Existing formatter tests keep passing unchanged; the spoken sentence for WMO 61 still reads "Light rain".
- [ ] Commit: `Move precipitation intensity onto WeatherCode`

---

### Task 2: WeatherProvider port, stub URL protocol and recorded fixtures

**Produces (main target, `Providers/WeatherProvider.swift`):**

```swift
protocol WeatherProvider: Sendable {
    func forecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast
    func search(_ query: String) async throws(WeatherError) -> [SavedLocation]
}
```

**Produces (test target, `Support/StubURLProtocol.swift`):**

```swift
final class StubURLProtocol: URLProtocol { … }

struct StubResponse: Sendable {
    var statusCode: Int = 200
    var body: Data = Data()
    var error: URLError.Code? = nil
}

enum StubNetwork {
    /// A fresh ephemeral session whose requests are answered by `respond`. Isolated per call.
    static func session(respond: @escaping @Sendable (URLRequest) -> StubResponse) -> URLSession
    static func fixture(_ name: String) throws -> Data          // loads Fixtures/<name>.json from Bundle.module
}
```

Isolation: `session(respond:)` generates a unique key, stores the closure in a lock-protected table under that key, and puts the key into the session configuration's `httpAdditionalHeaders` (`X-Stub-Key`). `StubURLProtocol` looks the closure up by that header. Two sessions created in parallel tests never see each other's responder.

**Fixtures:** record once with `curl`, commit, never refetch in tests. Save pretty-printed JSON under `Tests/WeatherFeatureTests/Fixtures/`:
- `forecast-vienna.json`: `https://api.open-meteo.com/v1/forecast?latitude=48.21&longitude=16.37&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,wind_gusts_10m&hourly=temperature_2m,weather_code,precipitation_probability,wind_gusts_10m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=10&forecast_hours=24`
- `forecast-honolulu.json`: same query with `latitude=21.31&longitude=-157.86` (a zone far from Europe, no daylight saving).
- `search-lisbon.json`: `https://geocoding-api.open-meteo.com/v1/search?name=Lisbon&count=10&language=en&format=json`
- `search-no-match.json`: same endpoint with `name=zzzzqqqq` (the response has no `results` key).
- `error-bad-latitude.json`: the forecast endpoint with `latitude=999` (HTTP 400, body `{"reason": …, "error": true}`).

Add `resources: [.copy("Fixtures")]` to the test target in `Package.swift`.

**Test cases:**
- [ ] Two sessions created back to back with different responders each receive their own response when both are used concurrently (`async let`).
- [ ] A responder returning `error: .notConnectedToInternet` makes `session.data(from:)` throw a `URLError` with that code.
- [ ] Every fixture file loads and parses as JSON; `forecast-vienna.json` has a top-level `timezone` string, 24 hourly times and 10 daily times.
- [ ] Commit: `Add WeatherProvider port, per-test URL stub and recorded Open-Meteo fixtures`

---

### Task 3: OpenMeteoProvider.forecast

**Produces:**

```swift
struct OpenMeteoProvider: WeatherProvider {
    init(session: URLSession = .shared, now: @escaping @Sendable () -> Date = { Date() })
}
```

`{ Date() }` as a default argument is the one allowed use of the real clock, because it is a pure-value default that tests override.

**Request:** `GET https://api.open-meteo.com/v1/forecast` with exactly the query items of the Vienna fixture URL in Task 2, where `latitude` and `longitude` come from `coordinate.rounded()` formatted with up to two decimals and a `.` decimal separator regardless of locale.

**Mapping:**
- `timeZone` = `TimeZone(identifier: response.timezone)`; if the identifier is unknown fall back to `TimeZone(secondsFromGMT: utc_offset_seconds)`; if both fail throw `.decoding`.
- `current`, `hourly[i]`, `daily[i]` map field by field. `is_day` 1 → true. `precipitation_probability` and `precipitation_probability_max` may be `null` → 0. `wind_gusts_10m` may be `null` → 0.
- `HourForecast.time` and sunrise/sunset: parse `yyyy-MM-dd'T'HH:mm` in the response's zone. `DayForecast.date`: parse `yyyy-MM-dd` as the start of that day in the response's zone.
- Arrays of different lengths inside `hourly` or `daily` → `.decoding`.
- `fetchedAt` = `now()`.

**Errors:** `URLError` codes `.notConnectedToInternet`, `.networkConnectionLost`, `.timedOut`, `.cannotFindHost`, `.cannotConnectToHost`, `.dnsLookupFailed`, `.dataNotAllowed`, `.internationalRoamingOff` → `.offline`; any other transport error → `.server`; HTTP status outside 200–299 → `.server`; JSON that does not decode or violates the mapping rules → `.decoding`. Task cancellation must propagate as cancellation where typed throws allows it; if it cannot, map it to `.offline` and say so in the report.

**Test cases (stubbed session, fixed `now`):**
- [ ] The request URL host, path and every query item equal the expected values for `Coordinate(48.20849, 16.37208)`: latitude `48.21`, longitude `16.37`, `timezone=auto`, `forecast_days=10`, `forecast_hours=24`, and no unit parameters.
- [ ] Vienna fixture: `timeZone.identifier == "Europe/Vienna"`, 24 hourly and 10 daily entries, `fetchedAt == now`, `current` values equal the fixture's numbers, hourly entries exactly one hour apart.
- [ ] Zone correctness: for the Honolulu fixture, `daily[0].date` equals midnight of the fixture's first daily date in `Pacific/Honolulu`, and it differs from the same string parsed in `Europe/Vienna`. The first hourly `time`, rendered with a `Pacific/Honolulu` calendar, has the hour written in the fixture string.
- [ ] A body with `precipitation_probability: [null, …]` maps those entries to 0.
- [ ] Mismatched array lengths → `.decoding`. Truncated JSON → `.decoding`. HTTP 400 with `error-bad-latitude.json` → `.server`. HTTP 500 → `.server`. `URLError(.notConnectedToInternet)` → `.offline`. `URLError(.timedOut)` → `.offline`. `URLError(.badServerResponse)` → `.server`.
- [ ] The mapped Vienna forecast feeds `DaySummary.make(from:now:)` without crashing and returns a non-nil value when `now` is the fixture's current time.
- [ ] Commit: `Add OpenMeteoProvider forecast with zone-correct mapping`

---

### Task 4: OpenMeteoProvider.search

**Request:** `GET https://geocoding-api.open-meteo.com/v1/search` with `name=<query trimmed>`, `count=10`, `language=<two-letter code>`, `format=json`. The language comes from a new initializer parameter `languageCode: String = "en"`. A trimmed query shorter than 2 characters returns `[]` without any request.

**Mapping:** each result → `SavedLocation(id:, name:, region: admin1, country:, coordinate:, timeZoneIdentifier: timezone)`. `id` is deterministic: `UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llx", openMeteoId))`, so the same city always gets the same id. Results without a `timezone`, or with an identifier `TimeZone(identifier:)` rejects, are skipped. A response without a `results` key is an empty array, not an error.

**Test cases:**
- [ ] Request host, path and query items for `"  Lisbon "` (trimmed name, count 10, language en, format json).
- [ ] `search-lisbon.json`: first result is Lisbon, country Portugal, region "Lisbon District", zone `Europe/Lisbon`, id `00000000-0000-0000-0000-` followed by the hex of 2267057 padded to 12 digits; mapping twice yields equal ids.
- [ ] `search-no-match.json` → `[]`. A one-character query → `[]` and the responder is never called.
- [ ] A result with a missing or invalid `timezone` is skipped while the others survive.
- [ ] Error mapping identical to Task 3 (offline, server, decoding), one test each.
- [ ] Commit: `Add OpenMeteoProvider place search`

---

### Task 5: Nightly live schema check, README

**Files:** create `Tests/WeatherFeatureTests/OpenMeteoLiveTests.swift`, `.github/workflows/ios-live.yml`; modify `Makefile`, `README.md`.

- [ ] Live suite: enabled only when the test process environment has `LIVE_TESTS=1` (`.enabled(if:)` trait), tagged `live`. Two tests against the real API with the real `URLSession.shared`: a forecast for `Coordinate(48.21, 16.37)` decodes, has a valid zone, 24 hourly and 10 daily entries and no value assertions; a search for "Lisbon" returns at least one result with a valid zone. With the variable absent the suite is skipped, so `make ios-test` and PR CI never touch the network.
- [ ] `make ios-test-live`: runs only that suite with `TEST_RUNNER_LIVE_TESTS=1` (`-only-testing:WeatherFeatureTests/OpenMeteoLiveTests`).
- [ ] `.github/workflows/ios-live.yml`: name `iOS live schema check`; triggers `schedule` (cron `17 3 * * *`) and `workflow_dispatch`; `permissions: contents: read`; one job on `macos-26`, 20 minute timeout; checkout pinned to `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`; select `/Applications/Xcode_26.5.app` and assert `Xcode 26.5` exactly like `ios.yml`; run `make ios-test-live`. It must check out `develop` explicitly (`ref: develop`), because scheduled workflows run from the default branch.
- [ ] Run `make ios-test-live` once locally and record the result in the report. If the network is unavailable, say so; do not fake it.
- [ ] README: Status paragraph becomes `Phase 1, iOS, step 3 of 6. The Open-Meteo provider maps live forecast and place-search responses into the app's model with each city's own time zone, tested against recorded fixtures. The store and cache arrive in step 4.` Keep the screenshot line. Add the build log row `| 2026-09-19 | iOS step 3: Open-Meteo provider, geocoding, zone-correct mapping, per-test URL stubs, nightly live schema check. |`.
- [ ] Commit: `Add nightly Open-Meteo live schema check; README step 3`
