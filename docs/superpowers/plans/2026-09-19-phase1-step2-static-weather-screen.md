# Phase 1, Step 2: Static Weather Screen from a Fixture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Weather tab renders a complete, accessible forecast screen in every state from an in-code fixture, covered by unit and snapshot tests, with a real screenshot in the README.

**Architecture:** Everything lands inside the single `WeatherFeature` target as folders: `Model/` (plain value types, the `WeatherStore` contract, the pure `DaySummary` rules, DEBUG fixtures) and `UI/` (formatter, views, screen state). `DaybookPlatform` gains `Theme/`. No networking, no store implementation and no provider yet.

**Tech Stack:** Swift 6 language mode, SwiftUI, Foundation format styles, Swift Testing, `pointfreeco/swift-snapshot-testing` 1.19.5 (test target only).

**Spec:** `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`, sections 4, 6, 7, 9, 10 and step 2 of section 12.

This plan gives exact file paths, exact public and internal signatures and exact test cases. Implementers write the bodies. Where a signature or a test case is given, use it verbatim.

## Global Constraints

- Every task is exactly one commit on branch `develop`. Never commit to `main`. Never push.
- Commit messages carry no `Co-Authored-By` trailer and no tool attribution.
- iOS 18.0 minimum, Xcode 26.5, Swift 6.3.2, Swift 6 language mode. Simulator: `platform=iOS Simulator,name=iPhone 17,OS=26.5`.
- The only third-party package is `https://github.com/pointfreeco/swift-snapshot-testing`, `exact: "1.19.5"`, and only `WeatherFeatureTests` may depend on it.
- `WeatherTab` stays the only `public` type of `WeatherFeature`. Everything else is internal.
- Layer rule: files under `UI/` must not name types declared under `Providers/` (`make lint` enforces it). `Model/` imports only Foundation and `DaybookPlatform`. `Model/` never imports SwiftUI.
- Model values are plain and metric: temperatures in Celsius `Double`, speeds in km/h `Double`, probabilities as `Int` percent. `Measurement` values are created only in the formatter.
- Every day and hour label is computed with the forecast's own `TimeZone`, never `TimeZone.current`. Never call `Date()` or `Locale.current` inside Model or formatter code; they are parameters.
- Tests use Swift Testing. No comments unless the reason would genuinely surprise a reader.
- TDD: write the failing test first, run `make ios-test`, see it fail, then implement.

## File Structure

```
ios/Packages/DaybookPlatform/Sources/DaybookPlatform/Theme/Theme.swift
ios/Packages/DaybookPlatform/Tests/DaybookPlatformTests/ThemeTests.swift
ios/Packages/WeatherFeature/Package.swift                                   (snapshot dependency, test target only)
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/WeatherCode.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/Forecast.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/SavedLocation.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/WeatherError.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/WeatherStore.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/DaySummary.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/Model/Forecast+Fixtures.swift   (#if DEBUG)
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherFormatter.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherScreenState.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherView.swift
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/Components/…            (header, hourly card, daily card, range bar, state views)
ios/Packages/WeatherFeature/Sources/WeatherFeature/UI/WeatherTab.swift        (modified)
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/…Tests.swift
ios/Packages/WeatherFeature/Tests/WeatherFeatureTests/__Snapshots__/          (recorded PNGs, committed)
Makefile                                                                     (ios-snapshots-record)
docs/images/weather-step2.png, README.md
```

---

### Task 1: Model value types and the WeatherStore contract

**Files:** create `Model/WeatherCode.swift`, `Model/Forecast.swift`, `Model/SavedLocation.swift`, `Model/WeatherError.swift`, `Model/WeatherStore.swift`; tests `WeatherCodeTests.swift`, `ForecastTests.swift`.

**Interfaces — Produces (use verbatim):**

```swift
enum WeatherCondition: String, Sendable, Codable, CaseIterable {
    case clear, mostlyClear, partlyCloudy, overcast, fog, drizzle, freezingDrizzle,
         rain, freezingRain, snow, snowGrains, rainShowers, snowShowers, thunderstorm, thunderstormWithHail, unknown
}

enum PrecipitationKind: String, Sendable, Codable { case rain, snow, thunderstorm }

struct WeatherCode: Sendable, Codable, Hashable {
    let wmo: Int
    init(wmo: Int)
    var condition: WeatherCondition { get }
    var precipitationKind: PrecipitationKind? { get }
    func symbolName(isDay: Bool) -> String          // SF Symbol name
}

struct CurrentConditions: Sendable, Codable, Equatable {
    let temperatureCelsius: Double
    let apparentTemperatureCelsius: Double
    let code: WeatherCode
    let isDay: Bool
    let windSpeedKmh: Double
    let windGustsKmh: Double
}

struct HourForecast: Sendable, Codable, Equatable {
    let time: Date
    let temperatureCelsius: Double
    let code: WeatherCode
    let isDay: Bool
    let precipitationProbability: Int
    let windGustsKmh: Double
}

struct DayForecast: Sendable, Codable, Equatable {
    let date: Date                 // start of the day in the forecast's time zone
    let code: WeatherCode
    let highCelsius: Double
    let lowCelsius: Double
    let precipitationProbability: Int
    let sunrise: Date
    let sunset: Date
}

struct Forecast: Sendable, Codable, Equatable {
    static let timeToLive: TimeInterval = 30 * 60
    let timeZone: TimeZone
    let current: CurrentConditions
    let hourly: [HourForecast]
    let daily: [DayForecast]
    let fetchedAt: Date
    func isStale(now: Date) -> Bool          // true when now - fetchedAt >= timeToLive
}

struct SavedLocation: Sendable, Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let region: String?
    let country: String?
    let coordinate: Coordinate
    let timeZoneIdentifier: String
}

enum WeatherError: Error, Sendable, Equatable { case offline, server, decoding, notFound }

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

**WMO mapping (complete, use verbatim):** 0 clear · 1 mostlyClear · 2 partlyCloudy · 3 overcast · 45, 48 fog · 51, 53, 55 drizzle · 56, 57 freezingDrizzle · 61, 63, 65 rain · 66, 67 freezingRain · 71, 73, 75 snow · 77 snowGrains · 80, 81, 82 rainShowers · 85, 86 snowShowers · 95 thunderstorm · 96, 99 thunderstormWithHail · anything else unknown.

**precipitationKind:** thunderstorm, thunderstormWithHail → `.thunderstorm`; snow, snowGrains, snowShowers → `.snow`; drizzle, freezingDrizzle, rain, freezingRain, rainShowers → `.rain`; all others → `nil`.

**symbolName(isDay:):** clear `sun.max.fill` / `moon.stars.fill` · mostlyClear and partlyCloudy `cloud.sun.fill` / `cloud.moon.fill` · overcast `cloud.fill` · fog `cloud.fog.fill` · drizzle, freezingDrizzle `cloud.drizzle.fill` · rain, freezingRain `cloud.rain.fill` · rainShowers `cloud.heavyrain.fill` · snow, snowGrains, snowShowers `cloud.snow.fill` · thunderstorm, thunderstormWithHail `cloud.bolt.rain.fill` · unknown `questionmark.circle`.

**Test cases:**
- [ ] Parameterized test over every WMO code listed above plus `4` and `-1` (unknown): condition matches the table.
- [ ] `precipitationKind` for 95 is thunderstorm, 73 snow, 61 rain, 80 rain, 3 nil, 45 nil.
- [ ] Day and night symbols differ for 0, 1, 2 and are equal for 3, 61, 95.
- [ ] `isStale`: fetchedAt = T. `now = T + 29 min 59 s` → false; `T + 30 min` → true; `T + 2 h` → true; `now` earlier than `fetchedAt` → false.
- [ ] `Forecast` survives a JSON encode and decode round trip with `JSONEncoder`/`JSONDecoder` using `.iso8601` dates and compares equal.
- [ ] Commit: `Add weather model types and the WeatherStore contract`

---

### Task 2: DaySummary rules

**Files:** create `Model/DaySummary.swift`; test `DaySummaryTests.swift`.

**Interfaces — Consumes:** Task 1 types. **Produces:**

```swift
enum DaySummary: Sendable, Equatable {
    case precipitation(kind: PrecipitationKind, from: Date, to: Date)
    case gusts(peakKmh: Double, at: Date)
    case warmingUp(toCelsius: Double, at: Date)
    case conditionAndHigh(code: WeatherCode, highCelsius: Double)

    static func make(from forecast: Forecast, now: Date) -> DaySummary?
}
```

**Rules, first match wins:**
1. Window = hourly entries with `time > now - 1 h` and `time < now + 12 h`, in order.
2. Precipitation: the first contiguous run of window entries with `precipitationProbability >= 50`. `from` = first entry's time, `to` = last entry's time + 1 h. `kind` = `.thunderstorm` if any entry in the run has that kind, else `.snow` if any has snow, else `.rain`.
3. Gusts: the window entry with the highest `windGustsKmh`, if that value is `>= 50`. Ties take the earliest.
4. Warming up: the window entry with the highest `temperatureCelsius`, if it exceeds `current.temperatureCelsius` by `>= 8`. Ties take the earliest.
5. Otherwise `.conditionAndHigh` from `daily.first`. If `daily` is empty return `nil`.

**Test cases** (build forecasts with a small test helper: 24 hourly entries from a fixed `now`, calm 15 °C, 0 % precipitation, gusts 10, code 1, then override single hours):
- [ ] Hours +2, +3, +4 at 70 % with code 61 → `.precipitation(.rain, from: now+2h, to: now+5h)`.
- [ ] Hours +2 at 60 % and +4 at 90 % (hour +3 at 10 %) → window is only hour +2: `to = now+3h`.
- [ ] A run containing code 95 → kind `.thunderstorm`; a run of code 71 → `.snow`.
- [ ] 49 % everywhere → not precipitation.
- [ ] 80 % only at hour +13 → ignored, falls through.
- [ ] Rain at +6 and gusts 80 at +1 → precipitation wins.
- [ ] Gusts 50.0 at +5 → `.gusts(peakKmh: 50, at: now+5h)`; gusts 49.9 → falls through.
- [ ] Current 10 °C, hour +6 at 18 °C → `.warmingUp(toCelsius: 18, at: now+6h)`; hour at 17.9 °C → falls through.
- [ ] Calm day → `.conditionAndHigh(code: daily[0].code, highCelsius: daily[0].highCelsius)`.
- [ ] Empty `daily` and calm hours → `nil`.
- [ ] Commit: `Add DaySummary rules`

---

### Task 3: Theme in DaybookPlatform

**Files:** create `DaybookPlatform/Theme/Theme.swift`; test `ThemeTests.swift`.

**Produces:**

```swift
public struct Theme: Sendable {
    public enum Sky: Sendable, CaseIterable { case clearDay, cloudyDay, rainDay, night }
    public var spacing: Spacing
    public struct Spacing: Sendable { public var small: CGFloat; public var medium: CGFloat; public var large: CGFloat }
    public static let standard: Theme
    public func skyGradient(_ sky: Sky) -> [Color]      // exactly two colors, top then bottom
    public var cardFill: Color { get }
    public var cardStroke: Color { get }
}

public extension EnvironmentValues { @Entry var theme: Theme = .standard }
```

`Theme.standard` spacing is 8, 16, 24. Sky gradients (top, bottom) as sRGB hex: clearDay `#2867BF`, `#86BAEE` · cloudyDay `#4B5A6B`, `#8696A6` · rainDay `#3E4C5C`, `#6F8191` · night `#0A0F2A`, `#2B3A67`. `cardFill` white at 17 % opacity, `cardStroke` white at 28 %. Text on these gradients is white; every gradient's lighter end must keep a contrast ratio of at least 4.5:1 against white for body text. If `#86BAEE` fails that, darken the bottom stop until it passes and record the value you chose.

**Test cases:**
- [ ] Every `Sky` case returns exactly two colors, and no two cases return the same pair.
- [ ] A pure helper `contrastRatio(_:_:)` (internal, WCAG relative luminance) is tested with black on white = 21 and white on white = 1, and every gradient stop has ratio `>= 4.5` against white.
- [ ] Commit: `Add Theme with sky gradients and environment entry`

---

### Task 4: WeatherFormatter

**Files:** create `UI/WeatherFormatter.swift`; test `WeatherFormatterTests.swift`.

**Produces:**

```swift
struct WeatherFormatter: Sendable {
    let locale: Locale
    let timeZone: TimeZone
    init(locale: Locale, timeZone: TimeZone)

    func temperature(_ celsius: Double) -> String                     // "18°", no scale letter
    func spokenTemperature(_ celsius: Double) -> String               // "18 degrees Celsius"
    func hourLabel(_ time: Date, now: Date) -> String                 // "Now" for the current hour, else "10" or "10 AM"
    func dayLabel(_ date: Date, now: Date) -> String                  // "Today" for the forecast zone's today, else "Tue"
    func spokenDayName(_ date: Date, now: Date) -> String             // "Today" or "Tuesday"
    func percent(_ value: Int) -> String                              // "70%"
    func clock(_ time: Date) -> String                                // "08:00" or "8:00 AM"
    func gusts(_ kmh: Double) -> String                               // "60 km/h" or "37 mph"
    func conditionName(_ condition: WeatherCondition) -> String       // "Partly cloudy"
    func summary(_ summary: DaySummary) -> String
    func spokenDay(_ day: DayForecast, now: Date) -> String
    func updatedAgo(_ fetchedAt: Date, now: Date) -> String           // "Updated 2 hr ago"
}
```

Use Foundation format styles with the injected `locale` and a `Calendar` whose `timeZone` is the injected one. Temperature uses `Measurement<UnitTemperature>.FormatStyle` with `usage: .weather`, zero fraction digits and `hidesScaleName: true`. English strings live in a String Catalog only if it costs nothing extra; otherwise plain English literals are acceptable in this step, because localization is not in the Phase 1 scope.

**Sentence shapes:** precipitation `"Rain likely 08:00–10:00"` (`Snow`, `Thunderstorms` for the other kinds, en dash between clock times) · gusts `"Windy around 15:00, gusts up to 60 km/h"` · warming `"Warming up to 21° by 15:00"` · condition `"Partly cloudy, high 21°"`. Spoken day: `"Tuesday. Light rain, 70 percent chance. Low 11 degrees Celsius, high 17 degrees Celsius."`; omit the chance clause when the probability is below 20.

**Test cases** (fixed instants; never the real clock):
- [ ] `en_AT`-like metric locale (`Locale(identifier: "en_AT")`): `temperature(18.4)` = `"18°"`, `temperature(-0.4)` has no negative zero.
- [ ] `en_US`: `temperature(18)` = `"64°"`; `gusts(60)` contains `"mph"`.
- [ ] Time zone: formatter in `America/Toronto`, `now` = 2026-09-21T23:30 Toronto. `dayLabel` of Toronto's 2026-09-21 is `"Today"` even though the same instant is 2026-09-22 in Vienna. With the same instants and a `Europe/Vienna` formatter the label is not `"Today"`.
- [ ] `hourLabel`: the hour containing `now` → `"Now"`; the next hour in `en_AT` → `"10"` style 24-hour digits; in `en_US` → contains `"AM"` or `"PM"`.
- [ ] `summary(.precipitation(kind: .rain, …))` in a 24-hour locale equals `"Rain likely 08:00–10:00"`.
- [ ] `spokenDay` equals the sentence above for a Tuesday with code 61, 70 %, low 11, high 17 in `en_AT`; the chance clause is absent at 10 %.
- [ ] `updatedAgo` two hours back contains `"2"` and an hour unit.
- [ ] Commit: `Add WeatherFormatter with zone-aware labels and spoken sentences`

---

### Task 5: DEBUG fixtures

**Files:** create `Model/Forecast+Fixtures.swift` (whole file inside `#if DEBUG`); test `FixtureTests.swift`.

**Produces:**

```swift
#if DEBUG
extension Forecast {
    static let fixtureNow: Date                 // 2026-09-21T09:41:00+02:00
    static let fixtureVienna: Forecast          // Europe/Vienna, partly cloudy 18°, rain window 12:00–14:00 on day 2 only
    static let fixtureToronto: Forecast         // America/Toronto, clear night 12°, fetched 2 h before fixtureNow
}
extension SavedLocation { static let fixtures: [SavedLocation] }   // Lisbon, Oslo, Toronto with real coordinates and zone ids
#endif
```

Vienna fixture values follow the approved mockup: current 18°, partly cloudy, H 21° L 11°; hourly from 09:00 with 18, 19, 20, 21, 21, 20 then plausible values to 24 entries; ten days starting Mon 2026-09-21 with lows and highs 11/21, 11/17 (code 61, 70 %), 9/15 (code 61, 55 %), 8/16 (3), 7/18 (2), 10/22 (0), 12/23 (0), 11/20 (2), 10/19 (3), 9/18 (61, 60 %). Hourly precipitation on day one stays below 50 %, so the Vienna summary is `.conditionAndHigh`. `fetchedAt` = `fixtureNow - 5 min` for Vienna.

**Test cases:**
- [ ] Vienna: 24 hourly entries strictly one hour apart, 10 daily entries strictly one calendar day apart in `Europe/Vienna`, `isStale(now: fixtureNow)` false, `DaySummary.make` = `.conditionAndHigh(code: WeatherCode(wmo: 2), highCelsius: 21)`.
- [ ] Toronto: `isStale(now: fixtureNow)` true, `current.isDay` false, time zone identifier `America/Toronto`.
- [ ] `SavedLocation.fixtures` has three entries with distinct ids and valid `TimeZone(identifier:)`.
- [ ] Commit: `Add DEBUG forecast fixtures`

---

### Task 6: WeatherView, all states, accessibility and snapshot tests

**Files:** modify `WeatherFeature/Package.swift`; create `UI/WeatherScreenState.swift`, `UI/WeatherView.swift`, files under `UI/Components/`; tests `WeatherViewSnapshotTests.swift` plus recorded images under `Tests/WeatherFeatureTests/__Snapshots__/`; modify `Makefile`.

**Produces:**

```swift
enum WeatherScreenState: Equatable {
    case locationNotAsked
    case locationDenied
    case loading
    case loaded(Forecast, placeName: String, isOffline: Bool)
    case failed(WeatherError)
}

struct WeatherView: View {
    init(state: WeatherScreenState, now: Date, locale: Locale,
         onAllowLocation: @escaping () -> Void = {}, onRetry: @escaping () -> Void = {})
}
```

**Layout, matching the approved mockup** (`weather-mockup.png` is not in the repo; the description is binding): full-screen sky gradient from `Theme` chosen by condition and `isDay`; centered header with a small "MY LOCATION" caption, place name, large thin temperature, condition name, `H:21°  L:11°`; a translucent rounded card with the day summary sentence, a divider and a horizontally scrolling hourly strip (label, symbol, temperature; first label "Now"); a second card titled "10-DAY FORECAST" with one row per day: day label, symbol with the precipitation percent underneath when it is 20 or more, low, range bar, high; footer text "Weather data by Open-Meteo.com" with "CC BY 4.0". The range bar is plain SwiftUI shapes: a track plus a gradient capsule positioned by the day's low and high within the ten-day minimum and maximum, and for today a dot at the current temperature. When `isOffline` or the forecast is stale, a line under the header shows "Offline · " plus `updatedAgo`.

**States:** `locationNotAsked` explains why location helps and has an "Allow Location" button calling `onAllowLocation`; `locationDenied` says saved cities still work and offers "Open Settings"; `loading` shows a `ProgressView` with the label "Loading forecast"; `failed` shows a message per `WeatherError` and a "Try Again" button calling `onRetry`. Use `ContentUnavailableView` where it fits.

**Accessibility (binding):**
- Text uses SwiftUI text styles; icon sizes and spacing use `@ScaledMetric`. When `dynamicTypeSize.isAccessibilitySize` is true, each day row stacks vertically: symbol and full day name, condition with chance, "Low 11°" and "High 21°", then a full-width range bar. Nothing may truncate at `.accessibility5`.
- Each day row is one accessibility element (`.accessibilityElement(children: .ignore)`) whose label is `WeatherFormatter.spokenDay`. Each hour cell is one element: "Now, partly cloudy, 18 degrees Celsius".
- "10-DAY FORECAST" and the place name carry `.isHeader`. Symbols inside combined elements are hidden from accessibility.
- The range bar view has `accessibilityChartDescriptor` describing the ten days' lows and highs.
- The loading state posts an announcement; the offline line is part of the header element.
- Buttons are at least 44 by 44 points. Animations respect `accessibilityReduceMotion`; card materials fall back to an opaque fill when `accessibilityReduceTransparency` is true.

**Snapshot tests** (`assertSnapshot(of:as:)` with `.image(layout: .fixed(width: 393, height: 852), traits:)`, `perceptualPrecision: 0.98`, fixed `now = Forecast.fixtureNow`, `locale = en_AT`):
- [ ] `loadedDay` (Vienna fixture) · `loadedNightOffline` (Toronto fixture, `isOffline: true`) · `loadedAccessibility5` (Vienna, `dynamicTypeSize(.accessibility5)`, height 1600) · `loading` · `failedOffline` · `locationNotAsked`.
- [ ] Recording: snapshot tests record only when the environment variable `SNAPSHOT_RECORD` equals `1`; otherwise a missing or different reference fails. Add `make ios-snapshots-record`, which runs the WeatherFeature tests with that variable passed through to the test process (`TEST_RUNNER_SNAPSHOT_RECORD=1` for `xcodebuild`).
- [ ] After recording, open every PNG and confirm it is not blank and that text, symbols and cards are visible. SwiftUI snapshots in a package test bundle without a host app are a known risk on iOS 26. If images come out blank or without text, stop and report BLOCKED with one sample image path; do not commit blank references.
- [ ] Also add non-snapshot tests: `spokenDay` label is what the row exposes (test the row's label builder function directly), and the range bar's fraction math (low and high mapped into 0…1 over the ten-day span, with a degenerate span of zero mapping to a full bar).
- [ ] Commit: `Add WeatherView with all states, accessibility and snapshot tests`

---

### Task 7: Wire the screen into WeatherTab, README screenshot

**Files:** modify `UI/WeatherTab.swift`, `Tests/WeatherFeatureTests/WeatherTabTests.swift`, `README.md`; create `docs/images/weather-step2.png`.

- [ ] `WeatherTab.body`: in DEBUG builds show `WeatherView(state: .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false), now: Forecast.fixtureNow, locale: .autoupdatingCurrent)`; in release builds keep the existing `ContentUnavailableView` placeholder. `WeatherTab` reads no clock yet; the real clock arrives with the view model in step 5. Keep `init(location:)` unchanged.
- [ ] Replace the `tab.body` test: keep a test that `WeatherTab(location:)` is constructible through the public API only (no `@testable`), and do not touch `body`.
- [ ] Run `make` (lint, tests, build, bundle check). All green.
- [ ] Screenshot: boot the `iPhone 17` iOS 26.5 simulator, install and launch the built app (`xcrun simctl install`, `xcrun simctl launch booted com.blue-studio.daybook`), wait for the screen, `xcrun simctl io booted screenshot docs/images/weather-step2.png`, then shut the simulator down. Confirm the image shows the forecast.
- [ ] README: under `## Status` write `Phase 1, iOS, step 2 of 6. The Weather tab renders a full forecast screen from a fixture in every state, with Dynamic Type, VoiceOver and snapshot tests. Live data arrives in step 3.` Add the image below that paragraph as `![Weather tab, step 2](docs/images/weather-step2.png)` with a width-limited HTML `<img>` if the raw image is wider than 400 px on GitHub. Add the build log row `| 2026-09-19 | iOS step 2: weather model, day summary rules, theme, formatter, WeatherView in all states, snapshot tests. |`.
- [ ] Commit: `Show the fixture forecast in WeatherTab; README screenshot`
