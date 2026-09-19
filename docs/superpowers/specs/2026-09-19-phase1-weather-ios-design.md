# Daybook Phase 1: Weather on iOS — design

Date: 2026-09-19. Status: draft for owner review. Nothing is built yet.

## 1. Goal

A Weather tab for iOS that the family checks in the morning: current location first, then saved family locations, each with current conditions, the next 24 hours and a 10-day forecast. Pure Swift first, shipped to TestFlight. Each forecast carries one plain-language morning summary line, such as "Rain likely 08:00–10:00".

Phase 1b, the Rust extraction, is on hold. It starts only when the owner says so, and nothing in Phase 1 depends on it. When it happens, networking, caching and mapping move into the shared Rust core in separate commits, so the git history shows the migration.

Phase 1 is done when:

1. The app shows a forecast for the current location and for saved cities, online and offline.
2. Every state in section 7 is reachable and covered by a test.
3. The accessibility checks in section 9 pass.
4. `make ios-test` is green locally and in GitHub Actions.
5. A build pushed as a `v*` tag appears in TestFlight for internal testers.

## 2. Decisions

| # | Decision | Reason |
|---|---|---|
| 1 | Swift first, Rust second (Phase 1b, on hold until the owner's go) | Owner wants the migration visible in git history |
| 2 | One SPM package per tab, one target inside, layers as folders | No layer modules, no import noise, `public` only on the tab entry |
| 3 | Folders depend downward only: UI → Store → Providers → Model | Any folder can become a target later by moving it; a CI grep enforces it |
| 4 | One shared package `DaybookPlatform`, single target | Coordinate, location and theme are needed by every future tab |
| 5 | App target imports only feature packages and `DaybookPlatform` | It never sees a store or a provider |
| 6 | Names: `WeatherStore` (not Repository), `WeatherProvider`, `ForecastCache` | Matches Apple vocabulary (`HKHealthStore`, `EKEventStore`); Android will say Repository |
| 7 | MVVM with `@Observable` view models; no TCA, no DI library | Stock tools are enough at this size |
| 8 | Initializer injection; defaults only for pure values, never for I/O | A test that forgets to inject must fail to compile, not hit the network |
| 9 | One provider (Open-Meteo); no merge strategy; MET Norway deferred | Merge logic arrives with the second provider |
| 10 | Location is one shared native actor with a waiting queue | One CoreLocation request at a time; the Rust core only ever gets coordinates |
| 11 | Time zone always comes from the API response for the coordinates | Remote cities and a manually set device clock both render correctly |
| 12 | Units: request metric, format with Foundation per locale | System temperature setting and UK mixed units work without a settings screen |
| 13 | Theme is a small value in SwiftUI `EnvironmentValues` | No design-token pipeline until Android is a second consumer |
| 14 | Swift Testing, hand-written fakes; `swift-snapshot-testing` is the only third-party package, test-only | Approved by owner |
| 15 | GitHub Actions only, Makefile for identical local and CI commands | Android, React Native and Rust join the same CI later; no fastlane, no Xcode Cloud |
| 16 | Release secrets live in the owner's password manager and a protected GitHub environment | Public repo; nothing secret ever enters git |
| 17 | TestFlight only for now | Open-Meteo's free tier is non-commercial; a store release needs a licence decision |
| 18 | iOS 18 minimum, Xcode 26.6 / Swift 6.3.3 pinned, Swift 6 language mode | Owner decision; two majors behind iOS 27 |
| 19 | Bundle identifier `com.blue-studio.daybook` | Owner decision |
| 20 | Hourly strip plus a 10-day forecast | Owner decision; the README scope line is updated to match |
| 21 | Rule-based morning summary line per location | Owner decision; the cheapest detail that serves "morning weather for the family" |

## 3. Layout

```
daybook/
├─ .github/workflows/ios.yml          test on PR and main, release on v* tags
├─ .github/workflows/ios-live.yml     nightly live schema check
├─ Makefile                           project, ios-test, ios-snapshots-record, ios-archive, ios-upload, lint-layers
├─ docs/superpowers/specs/            this document
└─ ios/
   ├─ project.yml                     XcodeGen; the .xcodeproj is generated, not committed
   ├─ App/                            DaybookApp.swift, Info.plist keys, PrivacyInfo.xcprivacy, assets
   └─ Packages/
      ├─ DaybookPlatform/             ONE target
      │    Sources/DaybookPlatform/Foundation/   Coordinate, LocatedPlace, LocationProviding, LocationError
      │    Sources/DaybookPlatform/Location/     LocationService actor (only CoreLocation user)
      │    Sources/DaybookPlatform/Theme/        Theme + EnvironmentValues entry
      └─ WeatherFeature/              ONE package = ONE tab = ONE target
           Sources/WeatherFeature/UI/            WeatherTab (public), views, view models
           Sources/WeatherFeature/Model/         Forecast, SavedLocation, WeatherCode, WeatherError, WeatherStore
           Sources/WeatherFeature/Store/         LiveWeatherStore, FileForecastCache, SavedLocationsFile
           Sources/WeatherFeature/Providers/     WeatherProvider, OpenMeteoProvider, FixtureProvider (DEBUG)
           Tests/WeatherFeatureTests/            tests, Fixtures/, __Snapshots__/
```

Imports in the whole app: App → WeatherFeature, App → DaybookPlatform, WeatherFeature → DaybookPlatform.

Phase 1 shows no tab bar, because a tab bar with one item is wrong on iOS. `DaybookApp` wraps tabs in a `TabView` from the moment a second tab exists. The five-tab bar in the mockup shows the destination.

## 4. Components

### DaybookPlatform

- `Coordinate`: latitude and longitude, `Sendable`, `Codable`, `Hashable`. `rounded()` returns two decimals, about 1 km, used for requests and cache keys.
- `LocatedPlace`: coordinate plus optional place name from reverse geocoding.
- `LocationProviding`: `authorization() async -> LocationAuthorization` and `current() async throws(LocationError) -> LocatedPlace`.
- `LocationAuthorization`: `notDetermined`, `denied` (also covers restricted), `authorized`. `LocationError`: `denied`, `unavailable`.
- `LocationService` actor. `CLLocationUpdate.liveUpdates()` delivers the fix and `CLServiceSession` holds when-in-use authorization. A `CLLocationManager` delegate is kept only to read authorization status. Waiting queue: one in-flight `Task` is shared by all concurrent callers, and a fix younger than 60 seconds is reused. Approximate location is accepted as is. A continuous stream is added when Health needs it, not before.
- `Theme`: semantic colors and spacing, read through `@Environment(\.theme)`.

### WeatherFeature / Model

- `Forecast`: `timeZone`, `current`, `hourly` (24 entries), `daily` (10 entries), `fetchedAt`. `isStale(now:)` is pure and uses a 30 minute TTL.
- `WeatherCode`: WMO code mapped to condition, SF Symbol name and spoken description, with day and night variants.
- `DaySummary.make(from:now:)`: a pure function that returns one sentence for the rest of today in the location's time zone. The first matching rule wins: a precipitation window of at least 50 % probability in the next 12 hours ("Rain likely 08:00–10:00", with snow or thunderstorm taken from the weather code), gusts of 50 km/h or more ("Windy this afternoon, gusts up to 60 km/h"), a rise of 8° or more from now to the high ("Warming up to 21° by 15:00"), otherwise the condition and the high ("Partly cloudy, high 21°"). Strings are localized and use the same formatters as the rest of the screen.
- `SavedLocation`: id, name, region, country, coordinate, time zone identifier.
- `WeatherError`: flat enum `offline`, `server`, `decoding`, `notFound`. Plain values only, so UniFFI can carry the same shapes in Phase 1b.
- `WeatherStore` protocol, the only thing the UI talks to:

```swift
protocol WeatherStore: Sendable {
    func cachedForecast(for coordinate: Coordinate) async -> Forecast?
    func refreshForecast(for coordinate: Coordinate) async throws(WeatherError) -> Forecast
    func searchPlaces(_ query: String) async throws(WeatherError) -> [SavedLocation]
    func savedLocations() async -> [SavedLocation]
    func save(_ location: SavedLocation) async
    func remove(id: SavedLocation.ID) async
    func reorder(_ ids: [SavedLocation.ID]) async
}
```

### WeatherFeature / Store

- `LiveWeatherStore`: composes a `WeatherProvider`, a `ForecastCache` and `now`. `refreshForecast` fetches, writes the cache and returns. It never decides staleness; `Forecast.isStale` does.
- `FileForecastCache`: one JSON file per rounded coordinate in Caches. A file that fails to decode is a miss and is deleted.
- `SavedLocationsFile`: JSON in Application Support, because Caches can be purged and saved cities are user data.
- `LiveWeatherStore.live()` is the one place that builds the production graph.

### WeatherFeature / Providers

- `WeatherProvider` (internal): `forecast(for:)` and `search(_:)`.
- `OpenMeteoProvider` on `URLSession`. Forecast: `api.open-meteo.com/v1/forecast` with current, hourly and daily variables including precipitation probability and wind gusts, `timezone=auto`, `forecast_days=10`, metric units. Search: `geocoding-api.open-meteo.com/v1/search`, which returns the city's time zone. DTOs are `private` to the file.
- `FixtureProvider`, `#if DEBUG` only: serves bundled JSON for previews and UI tests, selected by a launch argument.

### WeatherFeature / UI

- `WeatherTab(location:)` is the only public type. It builds `WeatherViewModel(store: LiveWeatherStore.live(), location:)`.
- `WeatherViewModel`, `@MainActor @Observable`, no default arguments.
- `WeatherView` (header, summary line above the hourly strip, 10-day list with range bars, attribution footer), `LocationsView` (current location first, saved cities with local time and their summary line, search, delete and reorder).

## 5. Data flow

```
WeatherTab appears
  → view model asks location.authorization()
      notDetermined → explain, button → location.current() shows the system prompt
      denied        → saved cities only, with a link to Settings
  → store.cachedForecast(coordinate)        show at once; mark "updated … ago" if stale
  → if nil, stale or pull-to-refresh: store.refreshForecast(coordinate)
      success → show fresh forecast
      failure → keep cached forecast with an offline note; if none, show the error state
```

## 6. Time zones and units

- Every day and hour label is formatted with `Forecast.timeZone`, never the device zone.
- "Today" is the first daily entry from the API, not a device-calendar comparison.
- If the current location has no cache and no network, labels use the device zone until the first response.
- Temperature, wind and precipitation are `Measurement` values formatted by Foundation, so locale and the system temperature setting apply, and VoiceOver reads "degrees Celsius".

## 7. States

`locationNotAsked`, `locationDenied`, `loading`, `loaded(fresh)`, `loaded(stale, offline)`, `failed(WeatherError)` with no cache, `refreshing`, and `emptySavedList`. Approximate location uses the same states and never claims a precise place.

Errors map to states in the view model. `OSLog` with subsystem `com.blue-studio.daybook` and categories `weather`, `location`; signposts wrap fetch and cache reads.

## 8. Privacy

- `NSLocationWhenInUseUsageDescription`: "Shows the weather where you are right now."
- `ITSAppUsesNonExemptEncryption = NO` from the first upload.
- `PrivacyInfo.xcprivacy` from step 1. The design avoids required-reason APIs: `fetchedAt` is stored inside the JSON, not read from file timestamps, and `UserDefaults` is not used. Anything added later is declared then.
- Coordinates are rounded to about 1 km before they leave the device. App Privacy declares coarse location, not linked to the user, not used for tracking, purpose app functionality.
- Footer attribution: "Weather data by Open-Meteo.com", CC BY 4.0.

## 9. Accessibility

Part of "done" for every screen:

- Dynamic Type through text styles and `@ScaledMetric`. At accessibility sizes day rows stack and nothing truncates.
- VoiceOver: one element per day with a full sentence, condition labels on icons, headings on section titles, announcements for loading and errors, and "updated … ago" for stale data. Saved rows expose delete and move as custom actions.
- The range bar shows low and high numerals at its ends and has an audio graph descriptor. A condition is never conveyed by color alone.
- 4.5:1 contrast on every background. Increase Contrast, Differentiate Without Color, Reduce Motion and Reduce Transparency are honored.
- 44 pt targets, named controls for Voice Control, sensible focus order for Full Keyboard Access and Switch Control. The stock tab bar supplies the large content viewer.
- Checks: `performAccessibilityAudit()` in the UI test with documented exclusions, one snapshot at the largest text size, and a manual VoiceOver pass per release candidate. The audit is a regression net, not proof.
- App Store Accessibility Nutrition Labels are claimed only after a manual pass of all common tasks for that label.

## 10. Testing

| Layer | Tool | Covers | Runs |
|---|---|---|---|
| UI smoke, 1–2 | XCUITest + accessibility audit | launch with `FixtureProvider`, open a saved city; location granted with `simctl privacy grant` | every PR |
| Snapshots, about 6 | swift-snapshot-testing, custom views only, `perceptualPrecision` 0.98 | loading, loaded, error, offline-stale, largest text size, dark | every PR, on the exact Xcode and simulator recorded in the Makefile in step 1; recording is a deliberate commit |
| Integration | Swift Testing | real `OpenMeteoProvider` + `LiveWeatherStore` + `FileForecastCache` in a temp directory | every PR |
| Unit | Swift Testing, hand-written fakes | DTO mapping, `WeatherCode`, day summary rules as a table of cases, time zones around midnight for a far city, locale formatting, staleness, cache corruption, offline to online, cancellation, view model states, waiting queue with a fake fix source | every PR |
| Live schema check, 1 | Swift Testing, tag `live` | Open-Meteo still has the fields and types we decode; never asserts values | nightly, own workflow |

- Network stubbing: each test builds its own `URLSession` with a stub `URLProtocol` and a per-test key that selects the response from a lock-protected table. No shared static handler, because Swift Testing runs tests in parallel in one process.
- Fixtures live inside the package in Phase 1. In Phase 1b they move to a repo-root `fixtures/` folder with golden expected outputs; `make fixtures` copies them into the package, the copy is committed, and CI fails on drift.
- Store contract tests are written against `WeatherStore` only. They are the suite that must pass unchanged in Phase 1b. Provider-level and clock-injection tests are Swift-implementation tests and are replaced by Rust tests then.
- `make lint-layers` fails if a file under `UI/` names a type from `Providers/`.

## 11. CI/CD

- `ios.yml`: runs on pull requests and on pushes to `develop` and `main`, path-filtered to `ios/**`, `scripts/**`, the Makefile and the workflow. `test` job on `macos-26` with an explicitly selected Xcode 26.6 runs `make ios-test`. Top-level `permissions: contents: read`. Third-party actions pinned by commit SHA. No `pull_request_target`.
- `release` job: only on `v*` tags, `needs: test`, environment `testflight` (deployment rule `v*`, owner as required reviewer). Full checkout, fails if the tag is not on `main`. Writes the API key to `$RUNNER_TEMP`, runs `make ios-archive` and `make ios-upload` with the key flags on both `xcodebuild` calls, deletes the key in an `always()` step. Signing is automatic and cloud-managed; no certificates or profiles are stored.
- Version: marketing version from the tag, build number = commit count on `main`, for example `0.1.0 (142)`.
- `ios-live.yml`: nightly schedule, runs only tests tagged `live`. A failure shows on that workflow and never blocks PRs.
- Owner's manual steps, once: register the bundle ID, create the app record, create an App Store Connect API key with the Admin role, run three `gh secret set` commands for the environment, approve release jobs.

## 12. Build order

Each step starts with failing tests and adds a row to the README build log. Every task is one commit, made directly on `develop`. `main` is kept for tagging and releases.

| # | Step | Verify |
|---|---|---|
| 1 | Project and CI: XcodeGen, two packages, Makefile, `ios.yml` test job, privacy manifest, Info.plist keys, layer lint | green Actions run |
| 2 | Static screen from a fixture: Model with `DaySummary`, `FixtureProvider`, `WeatherView` states, Theme, Dynamic Type and VoiceOver | snapshot tests; README screenshot |
| 3 | Open-Meteo provider and geocoding: DTO mapping, time zones, `WeatherCode` | stubbed-session tests with fixtures |
| 4 | Store and cache: cached and refresh paths, staleness, corruption, saved locations file | contract tests, integration test |
| 5 | Location and all states: `LocationService`, search and saved list, pull to refresh, offline note | view model tests, UI smoke test with audit, simulator run |
| 6 | Release pipeline to TestFlight. Can start any time after step 1, once the owner's manual steps are done | build visible in TestFlight |
| — | Phase 1b: Rust core. On hold, not part of this plan's execution until the owner's go | store contract tests pass unchanged |

## 13. Phase 1b outline (on hold)

- `core/` Rust crate with UniFFI, toolchain pinned in `rust-toolchain.toml` (1.87 or newer), iOS targets added, bindgen as a workspace member.
- A shared Swift package wraps the xcframework. Generated bindings sit in their own target with relaxed concurrency settings; a small mapping layer converts UniFFI records into the existing `Forecast` and `WeatherError`.
- `RustWeatherStore` replaces `LiveWeatherStore`; `Store/` and `Providers/` Swift code is deleted in the same series of commits. UI and view models do not change.
- The xcframework is built in its own workflow, not on every PR.
- Open decision for 1b: HTTP inside Rust (more shared code, but no ATS, system proxy or URLSession stubs) or an HTTP port implemented natively per platform (less shared, keeps platform networking and the Swift stubs).
- Publish binary size and cold-fetch numbers before and after.

## 14. Out of scope

Merge strategy and a second provider; location streaming, background location, "always" permission; widgets; settings screen; database; backend; design-token pipeline; App Store release; any Rust work until the owner's go.

## 15. Open items

1. Whether "Daybook" is free as a store name, and the Apple team ID. Both are needed only at step 6.
2. HTTP inside Rust or a native port. Decide if and when Phase 1b starts.
