# Phase 1, Step 5: Location and All States — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Weather tab shows real weather for where the user is, walks through every screen state from the spec (location not asked, denied, loading, loaded fresh, loaded stale and offline, failed, refreshing, empty saved list), lets the user search, save, reorder and pick cities, and is covered by view model tests, snapshots and a UI smoke test with an accessibility audit.

**Architecture:** A `LocationService` actor in `DaybookPlatform` puts a waiting queue and 60 s reuse in front of CoreLocation, which sits behind an internal `LocationFixSource` protocol so the queue is tested with a fake. A `@MainActor @Observable` `WeatherViewModel` in `UI/` owns the whole flow of spec section 5 over `any WeatherStore` and `any LocationProviding`, with one injected clock. `WeatherTab` builds the one clock and hands it to both `LiveWeatherStore.live(now:)` and the view model. `WeatherView` and `LocationsView` stay thin. `WeatherScreenState` gains no cases.

**Tech Stack:** Swift 6, CoreLocation (`CLServiceSession`, `CLLocationUpdate.liveUpdates()`, `CLLocationManager`, `CLGeocoder`), Observation, SwiftUI `.refreshable` / `.searchable`, Swift Testing, swift-snapshot-testing 1.19.5, XCTest for the UI test target only, XcodeGen 2.45.4.

**Spec:** `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`, sections 4, 5, 7, 8, 9, 10 and step 5 of section 12. Carry-over findings: `docs/superpowers/plans/2026-09-19-phase1-step5-notes.md` (deleted in Task 8, superseded by this plan).

Signatures, file names and test cases below are binding verbatim. Implementers write the bodies.

## Global Constraints

- Every task is exactly one commit on branch `develop`. Never commit to `main`. Never push.
- Commit messages: subject says what, body says why. No `Co-Authored-By` trailer of any kind and no tool attribution. After committing, check `git log -1 --format=%B` and amend if a trailer appeared.
- `make` (the default goal) is green before each commit. Task 7 and Task 8 additionally run `make ios-ui-test`.
- iOS 18.0 minimum, Xcode 26.5, Swift 6.3.2, Swift 6 language mode. Simulator: `platform=iOS Simulator,name=iPhone 17,OS=26.5`.
- No new third-party packages. `WeatherTab` stays the only `public` type in `WeatherFeature`. In `DaybookPlatform` only `LocationService` and its `init(now:)` become new public API.
- Layer rule: `UI/` never names types declared under `Providers/` (`make lint`). `UI/` may name `LiveWeatherStore` (it lives in `Store/`).
- No `Date()`, `Locale.current` or `TimeZone.current` outside `ios/App/DaybookApp.swift` and `Store/LiveWeatherStore+Live.swift` (plus the existing, untouched `now` default of `OpenMeteoProvider.init`). The one exception is the existing `locale: .autoupdatingCurrent` in the public `WeatherTab.init(location:)`, which has no other source for the view model's locale.
- One clock: the closure from `LiveWeatherStore.clock(arguments:)` is passed to `LiveWeatherStore.live(now:)` and to `WeatherViewModel`. `LocationService` gets `{ Date() }` from `DaybookApp.swift`; it uses the clock only for fix reuse.
- `OSLog` subsystem `com.replicantstudio.daybook`, categories `location` (`LocationService`) and `weather` (`WeatherViewModel`). An `OSSignposter` on the `weather` logger wraps the cache read and the refresh call.
- `WeatherScreenState` gains no cases. "Refreshing" is `WeatherViewModel.isRefreshing`; stale and offline is the existing `.loaded(_, placeName:, isOffline: true)`. `LocationError.unavailable` maps to `.failed(.notFound)`, which is the first producer of `.notFound`. An empty search is an empty list, never `.notFound`.
- The privacy manifest already declares coarse location, not linked, not tracking, app functionality, and no required-reason APIs. Nothing in this step adds one; `PrivacyInfo.xcprivacy` is not changed.
- Tests: Swift Testing for unit and snapshot tests, XCTest only in `DaybookUITests`. Swift Testing runs tests in parallel in one process: fakes are per-test instances, never a static shared handler. Tests never touch the network or real CoreLocation.
- Snapshots use the existing `screen(_:)` / `strategy(...)` helpers in `WeatherViewSnapshotTests.swift`; new snapshot tests are added to that suite. Recording is `make ios-snapshots-record` (it passes `TEST_RUNNER_SNAPSHOT_RECORD=1`, seen by the test as `SNAPSHOT_RECORD`). A task that changes pixels of an existing snapshot re-records that PNG in its own commit so `make` stays green; every recorded PNG is opened with the Read tool and checked by eye before committing.
- Shell: scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`. With pipefail, never pipe into `grep -q`; use plain `grep` (HANDOFF section 5).
- No comments unless the reason would genuinely surprise a reader.

## File Structure

```
ios/Packages/DaybookPlatform/Sources/DaybookPlatform/Foundation/LocationService.swift        LocationFixSource protocol + LocationService actor
ios/Packages/DaybookPlatform/Sources/DaybookPlatform/Foundation/CoreLocationFixSource.swift  CLServiceSession, liveUpdates, delegate, CLGeocoder
ios/Packages/DaybookPlatform/Tests/DaybookPlatformTests/LocationServiceTests.swift
ios/Packages/DaybookPlatform/Tests/DaybookPlatformTests/Support/FakeLocationFixSource.swift
ios/Packages/DaybookPlatform/Tests/DaybookPlatformTests/Support/TestClock.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherViewModel.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/LocationsView.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherTab.swift                     rewired to the view model
ios/Packages/WeatherFeature/Sources/WeatherFeature/Store/LiveWeatherStore+Live.swift        + location(arguments:fallback:), FixtureLocation (#if DEBUG)
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherView.swift                    + refreshable, locations button, isCurrentLocation
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/Components/WeatherHeader.swift       + isCurrentLocation, accessibility identifier
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/Components/WeatherStateViews.swift   loading view loses its announcement
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/Components/DayRow.swift              + accessibility identifier
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Support/FakeWeatherStore.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Support/FakeLocation.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/Support/TestClock.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/WeatherViewModelTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/WeatherViewModelLocationsTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/WeatherTabTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/WeatherFormatterTests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/WeatherViewSnapshotTests.swift       + new states, __Snapshots__ PNGs
ios/App/DaybookApp.swift                                                                   PlaceholderLocation deleted
ios/UITests/DaybookSmokeTests.swift
ios/project.yml                                                                            + DaybookUITests target, schemes block
Makefile                                                                                   + ios-ui-test
.github/workflows/ios.yml                                                                  + UI test step
README.md, HANDOFF.md, docs/images/weather-step5.png
```

---

### Task 1: LocationService

**Produces:**

```swift
// LocationService.swift
protocol LocationFixSource: Sendable {
    func authorization() async -> LocationAuthorization
    func fix() async throws(LocationError) -> Coordinate
    func placeName(for coordinate: Coordinate) async -> String?
}

public actor LocationService: LocationProviding {
    static let reuseInterval: TimeInterval = 60

    public init(now: @escaping @Sendable () -> Date)                              // uses CoreLocationFixSource()
    init(source: any LocationFixSource, now: @escaping @Sendable () -> Date)

    public func authorization() async -> LocationAuthorization                    // forwards to source
    public func current() async throws(LocationError) -> LocatedPlace
}

// CoreLocationFixSource.swift
struct CoreLocationFixSource: LocationFixSource { init() }

extension LocationAuthorization {
    init(_ status: CLAuthorizationStatus)     // notDetermined → .notDetermined; denied, restricted → .denied; authorizedWhenInUse, authorizedAlways → .authorized; @unknown default → .denied
}
```

**Behaviour of `current()`:**
- A cached `LocatedPlace` whose fix time `t` satisfies `now() - t < reuseInterval` is returned without calling the source.
- Otherwise, if a fetch is in flight, the caller awaits it. Otherwise one `Task<Result<LocatedPlace, LocationError>, Never>` is started: `source.fix()`, then `source.placeName(for:)`, then the result is cached with `now()` read after the fix arrives. All concurrent callers await that one task. A caller's cancellation does not cancel the shared task.
- On failure the error is returned to every waiting caller, nothing is cached, and the in-flight slot is cleared, so the next call starts a new fetch.
- Failures are logged on the `location` logger at `.error`, coordinates never logged.

**`CoreLocationFixSource` behaviour** (not unit tested; exercised by a device run — fixture mode never touches CoreLocation):
- `authorization()` reads `authorizationStatus` from a `CLLocationManagerDelegate` object that owns one `CLLocationManager`, created and used on the main actor. The delegate exists only for authorization status.
- `fix()` holds a `CLServiceSession(authorization: .whenInUse)` for its duration and iterates `CLLocationUpdate.liveUpdates()`. The first update with a non-nil `location` wins and returns its coordinate; approximate accuracy is accepted as is. An update with `authorizationDenied`, `authorizationDeniedGlobally` or `authorizationRestricted` throws `.denied`. The stream ending without a location throws `.unavailable`.
- `placeName(for:)` uses a new `CLGeocoder` per call, returns the first placemark's `locality`, else `name`, else nil. Any error returns nil. (`CLGeocoder` is deprecated in the iOS 26 SDK; the deprecation warning is accepted for iOS 18 support.)
- Isolation is the implementer's choice with two binding limits: `LocationService(now:)` must be callable from a property initializer of `DaybookApp`, and no `@unchecked Sendable` or `nonisolated(unsafe)`.

**Test support:** `TestClock` (a `final class: Sendable` over `Mutex<Date>` with `init(_ start: Date)`, `var now: Date`, `func advance(by: TimeInterval)`, `var closure: @Sendable () -> Date`). `FakeLocationFixSource`, an actor: `init(authorization: LocationAuthorization)`, `enqueueFix(_ result: Result<Coordinate, LocationError>)`, `setPlaceName(_ name: String?, for: Coordinate)`, `holdNextFix()`, `releaseFix()`, `waitUntilFixBegan() async` (bounded `Task.yield()` loop like `DelayedFirstWritePersistence`), `private(set) var fixCalls: Int`, `private(set) var geocodeCalls: [Coordinate]`. An empty queue throws `.unavailable`.

**Test cases** (`LocationServiceTests.swift`, clock starts at `Date(timeIntervalSince1970: 1_758_300_000)`):
- [ ] `authorization()` returns the source's value for each of the three cases.
- [ ] `LocationAuthorization(CLAuthorizationStatus)` maps all five known statuses as listed above.
- [ ] Three concurrent `current()` calls while the fix is held → after `releaseFix()` all three return the same `LocatedPlace` and `fixCalls == 1`.
- [ ] A second call 59 s after the first returns the cached place and `fixCalls == 1`.
- [ ] A second call exactly 60 s after the first fetches again: `fixCalls == 2` and the new coordinate is returned.
- [ ] The source throws `.denied` → `current()` throws `.denied`.
- [ ] The source throws `.unavailable` → `current()` throws `.unavailable`.
- [ ] A failed fetch does not poison the next call: first `.unavailable`, then a success → the second call returns the place and `fixCalls == 2`.
- [ ] Two concurrent callers of a held fix that then fails both receive the error, and a later call fetches again.
- [ ] `placeName` returning nil yields `LocatedPlace(coordinate: fix, name: nil)`; a name yields that name. `geocodeCalls` contains the fix coordinate exactly once per fetch, and never for a reused fix.
- [ ] `PrivacyInfo.xcprivacy`: no change needed (coarse location is already declared; no required-reason API is added). Say so in the commit body.
- [ ] Commit: `Add LocationService with a shared in-flight fix and 60 s reuse`. Body: why (one fix for concurrent callers, no prompt storm, CoreLocation behind a protocol so the queue is tested without a device).

---

### Task 2: WeatherViewModel

**Produces** (`UI/WeatherViewModel.swift`):

```swift
@MainActor @Observable
final class WeatherViewModel {
    static let currentLocationName = "Current Location"

    init(store: any WeatherStore, location: any LocationProviding, now: @escaping @Sendable () -> Date, locale: Locale)

    private(set) var state: WeatherScreenState            // starts as .loading
    private(set) var isRefreshing: Bool                   // starts false
    private(set) var loadingAnnouncements: Int            // starts 0; the view posts "Loading forecast" on each change
    let locale: Locale
    var currentDate: Date { get }                          // now()

    func start() async                                     // called once from .task
    func allowLocation() async
    func refresh() async                                   // pull to refresh
    func retry() async
}
```

**Flow** (spec section 5):
- `start()`: `location.authorization()`. `.notDetermined` → `.locationNotAsked`. `.denied` → `.locationDenied`. `.authorized` → `loadCurrent`.
- `allowLocation()`: `location.current()` (this shows the system prompt). Success → `loadCurrent` with that place. `.denied` → `.locationDenied`. `.unavailable` → `.failed(.notFound)`.
- `loadCurrent`: resolve the place with `location.current()` (errors as in `allowLocation`). Place name is `place.name ?? currentLocationName`. `store.cachedForecast(for: place.coordinate)`: non-nil → `.loaded(cached, placeName:, isOffline: cached.isStale(now: now()))`, then `refresh()` only if stale. Nil → `loadingAnnouncements += 1`, `.loading`, then `refresh()`.
- `refresh()`: no-op unless a place has been resolved. Serialised: while a refresh for the same place is in flight, a second call awaits the in-flight one and issues no second request. The refresh sets `isRefreshing = true`, re-resolves the place through `location.current()` (the service reuses a fix younger than 60 s), calls `store.refreshForecast`, then sets `isRefreshing = false`. Success → `.loaded(fresh, placeName:, isOffline: false)`. Failure with a forecast on screen → the same forecast with `isOffline: true`. Failure with nothing on screen → `.failed(error)`. A location failure during a refresh with a forecast on screen leaves the screen unchanged.
- `retry()`: `loadingAnnouncements += 1`, `.loading`, then `loadCurrent`.
- `loadingAnnouncements` increments only where written above: never on a refresh of a loaded screen.
- Refresh failures are logged on the `weather` logger at `.error` with the `WeatherError` case.

**Test support** (`Tests/WeatherFeatureTests/Support/`):
- `TestClock`: same shape as in Task 1 (the packages do not share test code).
- `FakeLocation`, an actor conforming to `LocationProviding`: `init(authorization: LocationAuthorization, current: [Result<LocatedPlace, LocationError>])` (the last result repeats), `setAuthorization(_:)`, `private(set) var currentCalls: Int`.
- `FakeWeatherStore`, an actor conforming to `WeatherStore`: `init(cached: [Coordinate: Forecast], saved: [SavedLocation])` keyed by rounded coordinate; `enqueueRefresh(_ result: Result<Forecast, WeatherError>)` (empty queue throws `.server`; a success is also written to `cached`); `enqueueSearch(_ result: Result<[SavedLocation], WeatherError>)`; `holdNextRefresh()`, `releaseRefresh()`, `waitUntilRefreshBegan() async` (bounded yield loop); in-memory `save` / `remove` / `reorder` with the `LiveWeatherStore` semantics; records `refreshCalls: [Coordinate]`, `cachedCalls: [Coordinate]`, `searchCalls: [String]`, `reorderCalls: [[SavedLocation.ID]]`.
- `vienna = LocatedPlace(coordinate: Coordinate(latitude: 48.2082, longitude: 16.3738), name: "Vienna")`, clock at `Forecast.fixtureNow` unless stated. `Forecast.fixtureVienna` was fetched 5 min before `fixtureNow`, so it is fresh at `fixtureNow` and stale at `fixtureNow + 26 min`.

**Test cases** (`WeatherViewModelTests.swift`, `@MainActor`, a fresh view model per test with `locale: Locale(identifier: "en_AT")`):
- [ ] Before `start()`: `state == .loading`, `isRefreshing == false`, `loadingAnnouncements == 0`.
- [ ] `.notDetermined` → `.locationNotAsked`; no `location.current()` call, no store call.
- [ ] `.denied` → `.locationDenied`; no store call.
- [ ] Authorized with a fresh cache → `.loaded(.fixtureVienna, placeName: "Vienna", isOffline: false)`, `refreshCalls` empty, `loadingAnnouncements == 0`.
- [ ] Authorized with a stale cache (clock `fixtureNow + 26 min`) and the refresh held → while held, `state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: true)` and `isRefreshing == true`; after release with a new forecast → `.loaded(new, "Vienna", false)` and `isRefreshing == false`.
- [ ] Authorized, no cache, refresh held → while held `state == .loading` and `loadingAnnouncements == 1`; after release → loaded, `loadingAnnouncements` still 1.
- [ ] No cache, refresh fails `.offline` → `.failed(.offline)`.
- [ ] Stale cache, refresh fails `.server` → `.loaded(.fixtureVienna, "Vienna", isOffline: true)`.
- [ ] Fresh cache, `refresh()` fails `.offline` → `.loaded(.fixtureVienna, "Vienna", isOffline: true)` and `loadingAnnouncements == 0`.
- [ ] Serialised: after a loaded `start()`, hold the refresh, call `refresh()` twice concurrently → after release both return, `refreshCalls.count == 1`.
- [ ] A `refresh()` after the previous one finished issues a new request (`refreshCalls.count == 2`).
- [ ] `refresh()` before any place is resolved (`.locationNotAsked`) makes no store call.
- [ ] `allowLocation()` succeeding → one `location.current()` call from `allowLocation` and the loaded state; `allowLocation()` with `.denied` → `.locationDenied`.
- [ ] `location.current()` throws `.unavailable` during `start()` → `.failed(.notFound)`.
- [ ] `retry()` from `.failed(.offline)` with a successful refresh → `loadingAnnouncements` goes from 1 to 2 and the state is loaded.
- [ ] `LocatedPlace.name == nil` → `placeName == "Current Location"`.
- [ ] The store receives the location's coordinate in both `cachedCalls` and `refreshCalls`.
- [ ] Staleness uses the injected clock: fresh cache at `fixtureNow + 24 min` → no refresh; at `fixtureNow + 26 min` → one refresh.
- [ ] Commit: `Add WeatherViewModel with serialised refresh and a single clock`. Body: why (the store does not coalesce, so appear plus pull-to-refresh must not fire two requests; the loading announcement moves to a state transition so it cannot repeat).

---

### Task 3: Wire WeatherTab to the view model

**Produces:**

```swift
public struct WeatherTab: View {
    public init(location: any LocationProviding)        // clock = LiveWeatherStore.clock(); store = LiveWeatherStore.live(now: clock); WeatherViewModel(store:, location:, now: clock, locale: .autoupdatingCurrent)
    init(viewModel: WeatherViewModel)                   // tests and previews; holds it in @State
    public var body: some View
}

// WeatherView.init gains, after onOpenSettings:
onRefresh: @escaping () async -> Void = {}
```

- `WeatherTab.body`: `WeatherView(state: viewModel.state, now: viewModel.currentDate, locale: viewModel.locale, onAllowLocation:, onRetry:, onOpenSettings:, onRefresh: { await viewModel.refresh() })`. Button callbacks wrap the async calls in `Task { }`. `onOpenSettings` opens `UIApplication.openSettingsURLString` through `@Environment(\.openURL)`. `.task { await viewModel.start() }`. `.onChange(of: viewModel.loadingAnnouncements) { AccessibilityNotification.Announcement("Loading forecast").post() }`.
- The DEBUG fixture branch and the Release `ContentUnavailableView` placeholder are deleted.
- `WeatherView`: the loaded `ScrollView` gets `.refreshable { await onRefresh() }`. No other state gets it.
- `WeatherLoadingView`: the `onAppear` announcement is deleted. The loading snapshot must not change.
- `ios/App/DaybookApp.swift`: `PlaceholderLocation` is deleted; the app holds `private let location = LocationService(now: { Date() })` and shows `WeatherTab(location: location)`.
- `Store/LiveWeatherStore+Live.swift` gains `static func location(arguments: [String] = ProcessInfo.processInfo.arguments, fallback: any LocationProviding) -> any LocationProviding`: in DEBUG with `-daybookFixtures` it returns `FixtureLocation` (a `#if DEBUG` struct in the same file: authorization `.authorized`, `current()` returns `LocatedPlace(coordinate: Coordinate(latitude: 48.2082, longitude: 16.3738), name: "Vienna")`), otherwise `fallback`. `WeatherTab.init(location:)` passes its argument through it, so fixture mode is fully deterministic (no CoreLocation, no geocoder, no permission prompt) for the UI test and screenshots. Test in `LiveWeatherStoreLiveTests`: with the argument the result is a `FixtureLocation`; without it the fallback is returned.

**Test cases** (`WeatherTabTests.swift`):
- [ ] `publicEntryAcceptsAnyLocationProvider` stays, now with `FakeLocation(authorization: .notDetermined, current: [.failure(.unavailable)])`; the private `StubLocation` is deleted.
- [ ] `WeatherTab(viewModel:)` accepts a view model built from `FakeWeatherStore`, `FakeLocation` and a `TestClock`, and its `body` can be hosted in a `UIHostingController` without crashing.
- [ ] `grep -rn 'PlaceholderLocation' ios` returns nothing; `grep -rn -e 'Date()' -e 'Locale.current' -e 'TimeZone.current' ios/Packages/*/Sources` returns only `LiveWeatherStore+Live.swift` and the existing `OpenMeteoProvider` default.
- [ ] `make` green, existing snapshots unchanged. Run the app once in the simulator with `-daybookFixtures`; it shows Vienna's forecast.
- [ ] Commit: `Wire WeatherTab to the view model and the real location service`. Body: why (the tab stops showing a fixture or a placeholder; one clock reaches both the store and the view model).

---

### Task 4: LocationsView and place selection

Saved-city logic is folded into `WeatherViewModel`, because selection changes the main screen's state and a second view model would need a callback into the first.

**Produces:**

```swift
enum SelectedPlace: Equatable {
    case current
    case saved(SavedLocation)
}

extension WeatherViewModel {                           // stored properties live in the class body
    private(set) var selectedPlace: SelectedPlace          // starts .current
    private(set) var currentPlaceName: String?             // last resolved current-location name
    private(set) var savedLocations: [SavedLocation]
    private(set) var savedForecasts: [SavedLocation.ID: Forecast]
    private(set) var searchResults: [SavedLocation]
    var searchQuery: String

    func loadSavedLocations() async                        // store.savedLocations(), then store.cachedForecast for each
    func search(_ query: String) async                     // trimmed empty → [] without a store call; error → [] and logged
    func save(_ location: SavedLocation) async             // store.save, clear searchQuery and searchResults, reload
    func remove(id: SavedLocation.ID) async                // store.remove, reload; removing the selected city selects .current
    func move(fromOffsets: IndexSet, toOffset: Int) async  // reorder locally, then store.reorder(ids)
    func select(_ place: SelectedPlace) async
}

struct LocationsView: View {
    init(viewModel: WeatherViewModel, onDone: @escaping () -> Void)
}

// WeatherView.init gains:
isCurrentLocation: Bool = true,
onShowLocations: @escaping () -> Void = {}

// WeatherHeader gains:
let isCurrentLocation: Bool                             // the "MY LOCATION" label shows only when true
```

**Selection:**
- `select(.current)` runs the Task 2 path (authorization first; denied → `.locationDenied`).
- `select(.saved(city))` uses `city.coordinate` and `placeName: city.name` with the same cache-then-refresh rules and announcements as `loadCurrent`, without touching location.
- `refresh()` refreshes the selected place. Serialisation applies per place: a refresh for another place does not join the in-flight one, and a result that arrives for a place no longer selected is dropped.

**View:**
- `WeatherView` shows a toolbar-style button (`Label("Locations", systemImage: "list.bullet")`, 44 pt, identifier `weather.locationsButton`) in the loaded, `locationDenied` and `failed` states. `WeatherTab` presents `LocationsView` in a `.sheet`.
- `LocationsView`: its own `NavigationStack`, title "Locations", a "Done" button calling `onDone`. `.task { await viewModel.loadSavedLocations() }`.
- With an empty `searchQuery`: first row "Current Location" (identifier `locations.currentLocation`) with `currentPlaceName` as subtitle when known; then one row per saved city: name, local time `WeatherFormatter(locale:, timeZone: TimeZone(identifier: city.timeZoneIdentifier)!).clock(viewModel.currentDate)`, and, when `savedForecasts[city.id]` exists, the summary line `DaySummary.make(from:now:)` formatted in that forecast's zone. Tapping a row calls `select` and `onDone`. `.onDelete` and `.onMove`. Each saved row also has `.accessibilityAction(named: "Delete")`, `"Move Up"` (not on the first) and `"Move Down"` (not on the last), calling the same view model methods. With no saved cities: a `ContentUnavailableView("No Saved Cities", systemImage: "building.2", description: Text("Search for a city to add it."))` below the current location row.
- With a non-empty `searchQuery`: rows for `searchResults` (name, then region and country); tapping one calls `save`. A query with no results shows `ContentUnavailableView.search(text:)`.
- `.searchable(text: $viewModel.searchQuery)` plus `.task(id: viewModel.searchQuery) { try? await Task.sleep(for: .milliseconds(300)); guard !Task.isCancelled else { return }; await viewModel.search(viewModel.searchQuery) }`. The debounce lives in the view; the view model's `search` is not debounced.

**Test cases** (`WeatherViewModelLocationsTests.swift`, `@MainActor`):
- [ ] `loadSavedLocations()` returns the store's list in order and fills `savedForecasts` only for cities with a cached forecast.
- [ ] `search("   ")` → `[]` and `searchCalls` empty; `search("Lis")` → the store's results; a store `.offline` → `[]`.
- [ ] `save(lisbon)` → the store holds it, `savedLocations` ends with it, `searchQuery == ""`, `searchResults` empty. Saving it again keeps one.
- [ ] `remove(id:)` removes it from the store and the list; removing the selected city sets `selectedPlace == .current`.
- [ ] `move(fromOffsets: [0], toOffset: 3)` over three cities → `reorderCalls.last` is `[oslo, toronto, lisbon]` ids and `savedLocations` matches.
- [ ] `select(.saved(lisbon))` with a fresh cache → `.loaded(.fixtureLisbon, placeName: "Lisbon", isOffline: false)`, no refresh, no `location.current()` call.
- [ ] `select(.saved(oslo))` with no cache and the refresh held → `.loading`, `loadingAnnouncements` incremented, `refreshCalls.last == oslo.coordinate`; after release → loaded "Oslo".
- [ ] While a Vienna refresh is held, `select(.saved(lisbon))` with a fresh cache → Lisbon is shown, and releasing the Vienna refresh leaves Lisbon on screen.
- [ ] While a Vienna refresh is held, `select(.saved(oslo))` with no cache issues its own request (`refreshCalls.count == 2`).
- [ ] `select(.current)` after a saved city with authorization `.denied` → `.locationDenied`.

**Snapshots** (added to `WeatherViewSnapshotTests`, built from a `WeatherViewModel` over a `FakeWeatherStore` after awaiting `loadSavedLocations()` / `search`):
- [ ] `locationsWithItems`: current location "Vienna" plus the three `SavedLocation.fixtures`, Lisbon with a cached forecast.
- [ ] `locationsEmpty`: no saved cities.
- [ ] `locationsSearchResults`: `searchQuery = "o"` and results `[oslo]`.
- [ ] Re-record `loadedDay`, `loadedNightOffline`, `loadedAccessibility5`, `failedOffline` and `locationDenied`, which now show the Locations button; check each PNG by eye.
- [ ] Commit: `Add LocationsView with search, saved cities and place selection`. Body: why (saved cities are the fallback when location is off; delete and reorder need VoiceOver actions, not just gestures).

---

### Task 5: Offline and stale note

`WeatherHeader` already renders `Offline · Updated … ago` when `isOffline || forecast.isStale(now:)`, through `WeatherFormatter.updatedAgo`, which uses `RelativeDateTimeFormatter` with the formatter's locale and the forecast's calendar, and `now` from the view. The existing `loadedNightOffline` snapshot (Toronto, fetched 2 h before `fixtureNow`, `isOffline: true`) covers the stale-offline state. This task is tests only.

**Test cases:**
- [ ] `WeatherFormatterTests.updatedAgoFollowsTheFormatterLocale`: `WeatherFormatter(locale: Locale(identifier: "de_AT"), timeZone: vienna).updatedAgo(now - 2 h, now: now)` contains `"2"` and `"Std"`.
- [ ] `WeatherFormatterTests.updatedAgoCountsMinutes`: `metricFormatter.updatedAgo(now - 45 min, now: now)` starts with `"Updated "` and contains `"45"`.
- [ ] Snapshot `loadedOfflineRecent`: `.loaded(.fixtureVienna, placeName: "Vienna", isOffline: true)` at `fixtureNow`, which shows `Offline · Updated 5 min. ago` (the pull-to-refresh failure on a fresh cache).
- [ ] Commit: `Test the offline note's relative time and locale`. Body: why (the header already did the work; the stale state needed proof in another locale and for a fresh-but-offline forecast).

---

### Task 6: Snapshots for the remaining states

States with no snapshot yet after Tasks 4 and 5. "Refreshing" is the system `.refreshable` indicator and is not snapshotted. `strategy(...)` gains a `style: UIUserInterfaceStyle = .light` parameter.

- [ ] `loadedSavedCity`: `.loaded(.fixtureLisbon, placeName: "Lisbon", isOffline: false)` with `isCurrentLocation: false`; no "MY LOCATION" label.
- [ ] `loadedDark`: `loadedDay` with `style: .dark`.
- [ ] `locationsDark`: `locationsWithItems` with `style: .dark`.
- [ ] `locationsAccessibility5`: `locationsWithItems` at `.accessibility5`, height 1600; nothing truncates.
- [ ] Record with `make ios-snapshots-record`, then run `make` without recording and confirm it is green. Open every new PNG with the Read tool before committing.
- [ ] Commit: `Add snapshots for saved-city, dark and large-text states`. Body: why (spec section 10 lists dark and largest text; recording is a deliberate commit).

---

### Task 7: UI smoke test with accessibility audit

**Produces:**

```swift
// ios/UITests/DaybookSmokeTests.swift
final class DaybookSmokeTests: XCTestCase {
    @MainActor func testFixtureLaunchShowsTheForecastAndPassesTheAudit() throws
    @MainActor func testLocationsListOpensAndPassesTheAudit() throws
}
```

**Accessibility identifiers** added in WeatherFeature: `weather.header` on `WeatherHeader`'s combined element, `weather.dayRow` on every `DayRow`, plus `weather.locationsButton` and `locations.currentLocation` from Task 4.

**Tests:** `continueAfterFailure = false`. Each test launches `XCUIApplication()` with `launchArguments = ["-daybookFixtures"]`.
- [ ] Test 1: `app.otherElements["weather.header"]` (or any element type via `app.descendants(matching: .any)["weather.header"]`) exists within 30 s and its `label` contains `"Vienna"`; `app.descendants(matching: .any).matching(identifier: "weather.dayRow").firstMatch` exists; `try app.performAccessibilityAudit { issue in ... }`.
- [ ] Test 2: tap `weather.locationsButton`, `locations.currentLocation` exists within 10 s, then `performAccessibilityAudit`.
- [ ] Exclusions: the handler returns `true` only for an issue matched by audit type and element identifier, and every such branch has a comment saying why it is a false positive. Start with none; add one only after reading the failure, never a blanket type.

**`ios/project.yml`:**

```yaml
  DaybookUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - UITests
    dependencies:
      - target: Daybook
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.replicantstudio.daybook.uitests
        GENERATE_INFOPLIST_FILE: YES
        TEST_TARGET_NAME: Daybook
schemes:
  Daybook:
    build:
      targets:
        Daybook: all
        DaybookUITests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - DaybookUITests
    archive:
      config: Release
```

Fixture mode uses `FixtureLocation` (Task 3), so no simctl privacy grant or location pin is needed; `xcodebuild test` boots the simulator itself.

**`Makefile`:**

```make
.PHONY: ios-ui-test
ios-ui-test: project
	xcodebuild test -project ios/Daybook.xcodeproj -scheme Daybook -only-testing:DaybookUITests -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -quiet CODE_SIGNING_ALLOWED=NO
```

`ios-ui-test` is not added to `all`; CI runs it as its own step.

**`.github/workflows/ios.yml`**, `test` job: raise `timeout-minutes` from 30 to 45 and add after `Verify bundle`:

```yaml
      - name: UI test
        run: make ios-ui-test
```

- [ ] `make ios-ui-test` passes locally twice in a row.
- [ ] `make ios-build ios-verify-bundle` and `make ios-archive ios-verify-archive VERSION=0.0.0 BUILD=1` still pass with the explicit scheme.
- [ ] `ruby -ryaml -e 'y = YAML.load_file(".github/workflows/ios.yml"); names = y["jobs"]["test"]["steps"].map { |s| s["name"] }; abort("order") unless names.index("UI test") == names.index("Verify bundle") + 1; puts "ok"'` prints `ok`.
- [ ] Commit: `Add a UI smoke test with an accessibility audit`. Body: why (the audit is the regression net from spec section 9; fixture mode fakes location so the test never sees a system prompt or the network).

---

### Task 8: README, screenshot and handoff

- [ ] Screenshot, from the repo root after `make ios-build`:

```bash
xcrun simctl bootstatus "iPhone 17" -b
xcrun simctl install booted ios/build/DerivedData/Build/Products/Debug-iphonesimulator/Daybook.app
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100
xcrun simctl launch booted com.replicantstudio.daybook -daybookFixtures
xcrun simctl io booted screenshot docs/images/weather-step5.png
xcrun simctl status_bar booted clear
```

  Wait until the forecast is visible before the screenshot. Open the PNG with the Read tool and confirm it shows Vienna's forecast.
- [ ] README Status paragraph becomes: `Phase 1, iOS, complete: all 6 steps. The Weather tab shows the forecast where you are, keeps working offline from a file cache with an "updated … ago" note, and lets you search, save and reorder cities. Releases go to TestFlight from a tag.` The image line becomes `<img src="docs/images/weather-step5.png" alt="Weather tab, step 5" width="300">`.
- [ ] README build log row: `| 2026-09-24 | iOS step 5: LocationService, WeatherViewModel with serialised refresh, saved cities and search, pull to refresh, offline note, UI smoke test with accessibility audit. |`
- [ ] Delete `docs/superpowers/plans/2026-09-19-phase1-step5-notes.md` (superseded by this plan).
- [ ] `HANDOFF.md`, short edits only: section 1 says all six steps of Phase 1 are done and the next build shows real weather; section 3 drops the `PlaceholderLocation` and "no plan yet" items, notes `.notFound` now means location unavailable and points to this plan; section 4 becomes: push `develop` and watch CI, run on a real iPhone for the permission flow, release `0.2.0` with `scripts/tag-release.sh`.
- [ ] `make` and `make ios-ui-test` green.
- [ ] Commit: `Close Phase 1 on iOS: README step 5 and handoff`. Body: why (the README and handoff are the record a reader without chat history starts from; the step 5 notes are superseded by the plan).
