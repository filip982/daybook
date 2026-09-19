# Phase 1, Step 4: Store and Cache — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tested `LiveWeatherStore` that serves the last forecast instantly from a JSON file cache, refreshes from the provider, survives corrupt files and no network, and persists the user's saved cities.

**Architecture:** A new `Store/` folder inside the single `WeatherFeature` target. `LiveWeatherStore` is an actor implementing the existing `WeatherStore` contract by composing three small parts behind internal protocols: a `WeatherProvider`, a `ForecastCache` and a `SavedLocationsPersistence`. Staleness is not decided here; `Forecast.isStale(now:)` already owns it. A DEBUG-only `FixtureProvider` and the `LiveWeatherStore.live()` factory close the step. Nothing is wired into the UI yet; the view model arrives in step 5.

**Tech Stack:** Swift 6 actors, Foundation `FileManager` and `JSONEncoder`, Swift Testing, the existing `StubNetwork` helper and recorded fixtures.

**Spec:** `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`, sections 4 (Store, Providers), 5, 8, 10 and step 4 of section 12.

Signatures, file names, on-disk formats and test cases below are binding verbatim. Implementers write the bodies.

## Global Constraints

- Every task is exactly one commit on branch `develop`. Never commit to `main`. Never push.
- Commit messages carry no `Co-Authored-By` trailer and no tool attribution.
- iOS 18.0 minimum, Xcode 26.5, Swift 6.3.2, Swift 6 language mode. Simulator: `platform=iOS Simulator,name=iPhone 17,OS=26.5`.
- No new third-party packages. `WeatherTab` stays the only `public` type.
- Layer rule: `UI/` never names types declared under `Providers/` (`make lint`). `Store/` may use `Providers/` and `Model/`. `Model/` imports only Foundation and `DaybookPlatform`.
- Cache keys and every provider call use `coordinate.rounded()`.
- Never call `Date()` in store or cache code. The one allowed real clock is the default argument of `LiveWeatherStore.live(now:)`, and that same closure is handed to the provider, so `fetchedAt` and staleness share one clock.
- The privacy manifest declares no required-reason APIs. Do not read file modification dates, do not use `UserDefaults`. `fetchedAt` lives inside the JSON.
- Forecast cache files live in the Caches directory. Saved locations live in Application Support, because Caches can be purged and saved cities are user data.
- The cache is best effort: a failed write or an unreadable file never throws to the caller and never crashes.
- Tests never touch the network and never write outside a unique temporary directory they create and remove.
- Tests use Swift Testing. No comments unless the reason would genuinely surprise a reader.

## File Structure

```
ios/Packages/WeatherFeature/Sources/WeatherFeature/Store/ForecastCache.swift             protocol + FileForecastCache
ios/Packages/WeatherFeature/Sources/WeatherFeature/Store/SavedLocationsPersistence.swift  protocol + SavedLocationsFile
ios/Packages/WeatherFeature/Sources/WeatherFeature/Store/LiveWeatherStore.swift           actor + live() factory
ios/Packages/WeatherFeature/Sources/WeatherFeature/Providers/FixtureProvider.swift        #if DEBUG
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Support/TemporaryDirectory.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Support/FakeWeatherProvider.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/FileForecastCacheTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/SavedLocationsFileTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/LiveWeatherStoreTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/WeatherStoreContractTests.swift
README.md
```

---

### Task 1: FileForecastCache

**Produces:**

```swift
protocol ForecastCache: Sendable {
    func forecast(for coordinate: Coordinate) async -> Forecast?
    func store(_ forecast: Forecast, for coordinate: Coordinate) async
}

actor FileForecastCache: ForecastCache {
    init(directory: URL)
    static func defaultDirectory() -> URL        // <Caches>/Forecasts
}
```

**On disk:** one file per rounded coordinate, named `forecast_<lat>_<lon>.json` with two decimals and a `.` separator on any locale, for example `forecast_48.21_16.37.json` and `forecast_-33.87_151.21.json`. JSON from a plain `JSONEncoder` (default date strategy, so `Date` round-trips exactly). Written atomically. The directory is created on first write. A file that fails to decode is a miss and is deleted.

**Test cases** (each test creates its own temporary directory through a `TemporaryDirectory` test helper that removes it afterwards):
- [ ] Store then read returns an equal `Forecast` (use `Forecast.fixtureVienna`).
- [ ] Reading before any write returns nil and creates nothing.
- [ ] Two coordinates that round to the same value share one file; two that round differently do not.
- [ ] The file name for `Coordinate(latitude: -33.86785, longitude: 151.20732)` is exactly `forecast_-33.87_151.21.json`.
- [ ] A file containing garbage bytes → nil, and the file no longer exists afterwards. A truncated valid JSON file behaves the same.
- [ ] Storing twice keeps only the newer forecast.
- [ ] A directory URL that cannot be created (a path below a regular file) → `store` returns without throwing or crashing and a later read returns nil.
- [ ] A fresh `FileForecastCache` pointed at the same directory reads what an earlier instance wrote.
- [ ] Commit: `Add FileForecastCache with corruption handling`

---

### Task 2: SavedLocationsFile

**Produces:**

```swift
protocol SavedLocationsPersistence: Sendable {
    func load() async -> [SavedLocation]
    func save(_ locations: [SavedLocation]) async
}

actor SavedLocationsFile: SavedLocationsPersistence {
    init(fileURL: URL)
    static func defaultFileURL() -> URL          // <Application Support>/Daybook/saved-locations.json
}
```

JSON array, written atomically, parent directory created on first save. A missing file is an empty list. A corrupt file is an empty list and is left in place until the next save overwrites it.

**Test cases:**
- [ ] Missing file → `[]`. Save three `SavedLocation.fixtures`, load → same three in the same order.
- [ ] A fresh instance on the same URL loads what an earlier one saved.
- [ ] Garbage bytes → `[]` and no crash; a following save then load returns the saved list.
- [ ] Saving an empty list then loading returns `[]`.
- [ ] Commit: `Add SavedLocationsFile persistence`

---

### Task 3: LiveWeatherStore

**Produces:**

```swift
actor LiveWeatherStore: WeatherStore {
    init(provider: any WeatherProvider, cache: any ForecastCache, savedLocations: any SavedLocationsPersistence)
}
```

**Behaviour:**
- `cachedForecast(for:)` → `cache.forecast(for: coordinate.rounded())`. No network.
- `refreshForecast(for:)` → `provider.forecast(for: coordinate.rounded())`; on success store it in the cache under the rounded coordinate and return it; on failure rethrow the `WeatherError` and leave the cache untouched.
- `searchPlaces` forwards to the provider.
- `savedLocations()` loads the list. `save(_:)` appends unless a location with the same `id` exists, in which case the list is unchanged. `remove(id:)` removes it if present. `reorder(_:)` orders the list by the given ids; ids that are not in the list are ignored, and locations whose ids were not mentioned keep their relative order at the end.

**Test support:** `FakeWeatherProvider` in the test target, an actor with a queue of scripted results per method and a record of received calls.

**Unit test cases (fake provider, real `FileForecastCache` and `SavedLocationsFile` in a temporary directory):**
- [ ] Refresh success returns the provider's forecast and a following `cachedForecast` returns the same value without another provider call.
- [ ] The provider receives the ROUNDED coordinate, and two nearby coordinates hit one cache entry.
- [ ] Refresh failure with `.offline` throws `.offline` and an earlier cached forecast is still returned by `cachedForecast`.
- [ ] Refresh failure with an empty cache throws and `cachedForecast` stays nil.
- [ ] `cachedForecast` never calls the provider.
- [ ] Saved locations: save adds in order; saving the same id twice keeps one; remove deletes; remove of an unknown id is a no-op; reorder with a full list, a partial list and a list containing an unknown id behaves as specified; every mutation survives a new `LiveWeatherStore` built on the same file.
- [ ] Commit: `Add LiveWeatherStore composing provider, cache and saved locations`

---

### Task 4: WeatherStore contract tests through the stubbed network

These are the tests meant to survive Phase 1b. They know only `any WeatherStore` and HTTP fixtures.

**File:** `WeatherStoreContractTests.swift`. A single helper `makeStore(respond:) -> (store: any WeatherStore, cleanup: …)` builds `LiveWeatherStore` over a real `OpenMeteoProvider` on `StubNetwork.session`, with a real file cache and saved-locations file in a temporary directory and a fixed `now`. Every test below uses only the `any WeatherStore` value.

- [ ] Refresh with `forecast-vienna.json` → a forecast in `Europe/Vienna` with `fetchedAt == now`; `cachedForecast` then returns an equal value.
- [ ] Offline after a successful refresh: the second refresh throws `.offline`, `cachedForecast` still returns the first forecast.
- [ ] Offline with nothing cached: refresh throws `.offline`, `cachedForecast` is nil.
- [ ] HTTP 500 → `.server`; truncated body → `.decoding`; neither writes a cache entry.
- [ ] A corrupt cache file written by the test before the store is used → `cachedForecast` is nil and a refresh then repairs it.
- [ ] Search with `search-lisbon.json` returns Lisbon first; saving it, reading saved locations from a second store instance on the same directory returns it with the same id.
- [ ] Staleness end to end: refresh at `now`, then `forecast.isStale(now: now + 29 min)` is false and `isStale(now: now + 31 min)` is true.
- [ ] Commit: `Add WeatherStore contract tests over the stubbed network`

---

### Task 5: FixtureProvider, the live() factory and README

**Produces:**

```swift
#if DEBUG
struct FixtureProvider: WeatherProvider { init() }      // forecast → Forecast.fixtureVienna for any coordinate except Toronto's rounded one, which gets fixtureToronto; search → SavedLocation.fixtures filtered by a case-insensitive prefix match on name
#endif

extension LiveWeatherStore {
    static let fixtureLaunchArgument = "-daybookFixtures"
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments,
                     now: @escaping @Sendable () -> Date = { Date() }) -> LiveWeatherStore
}
```

`live` builds `FileForecastCache(directory: .defaultDirectory())`, `SavedLocationsFile(fileURL: .defaultFileURL())` and an `OpenMeteoProvider(session: .shared, languageCode: <two-letter code of Locale.autoupdatingCurrent, "en" if unknown>, now: now)`. In DEBUG builds, when `arguments` contains `fixtureLaunchArgument`, the provider is `FixtureProvider()` instead. Release builds never reference `FixtureProvider`.

- [ ] Tests: `FixtureProvider` returns the Vienna fixture for an arbitrary coordinate and the Toronto fixture for `SavedLocation.fixtures`' Toronto coordinate; search "os" → Oslo only, "" → `[]`. `live(arguments: ["app", "-daybookFixtures"], now:)` yields a store whose refresh returns the fixture without any network (assert by running it with no stub session and no connectivity assumptions; the fixture path performs no I/O besides the cache write into the default Caches directory, so clean that file up after the test or accept a temporary cache entry and say so).
- [ ] `make lint` stays green: `FixtureProvider` is referenced only from `Store/` and tests.
- [ ] README: Status paragraph becomes `Phase 1, iOS, step 4 of 6. A store serves the last forecast from a file cache, refreshes from Open-Meteo, survives corrupt files and no network, and keeps saved cities in Application Support. The screen gets live data and location in step 5.` Keep the screenshot line. Add the build log row `| 2026-09-19 | iOS step 4: forecast file cache, saved locations file, LiveWeatherStore, contract tests over a stubbed network, debug fixture provider. |`.
- [ ] Commit: `Add FixtureProvider and the live store factory; README step 4`
