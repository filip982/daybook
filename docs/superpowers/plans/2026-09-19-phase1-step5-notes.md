# Notes carried into Phase 1, Step 5 (location, view model, all states)

Status on 2026-09-19: steps 1 to 4 are done on `develop` and green in CI. Step 5 has no plan yet. Step 6 (TestFlight) waits for the owner's manual Apple steps. Phase 1b (Rust) is on hold.

Decisions and findings from earlier reviews that step 5 must honour:

- One clock. `LiveWeatherStore.clock(arguments:)` returns the app clock; in DEBUG with `-daybookFixtures` it is pinned to `Forecast.fixtureNow`. `WeatherTab` must hand that same closure to `LiveWeatherStore.live(now:)` and to the view model.
- The store does not coalesce refreshes. The view model serialises them, so appear plus pull-to-refresh cannot issue two requests.
- `WeatherError.notFound` is never produced yet. Decide in step 5 whether the UI needs it; an empty search is an empty list.
- HTTP 429 surfaces as `.server`. No retry or backoff exists.
- The "Loading forecast" VoiceOver announcement fires from `onAppear` of the loading view and can repeat. Move it to a state transition in the view model.
- `WeatherTab` currently shows the Vienna fixture in DEBUG and a placeholder in Release, and ignores its `location` parameter. Step 5 replaces both branches with the real view model; `PlaceholderLocation` in `ios/App/DaybookApp.swift` is deleted when `LocationService` exists.
- `LocationService` (DaybookPlatform): waiting queue with one in-flight task, 60 second reuse, authorization state from a `CLLocationManager` delegate, fix from `CLLocationUpdate.liveUpdates()`, `CLServiceSession` for when-in-use. A continuous stream waits for Health.
- States to cover: location not asked, denied, loading, loaded fresh, loaded stale and offline, failed with no cache, refreshing, empty saved list. Approximate location uses the same states.
- LocationsView: current location first, saved cities with local time and their summary line, search, delete and reorder exposed as VoiceOver custom actions.
- UI smoke test: launch with `-daybookFixtures`, grant location with `simctl privacy grant`, run `performAccessibilityAudit()` with documented exclusions.
- A tab bar appears only when a second tab exists.
- `.github/workflows/ios-live.yml` is dormant until the file exists on `main`; scheduled and manual runs register only from the default branch.
- Commit style from here on: one commit per logical step, subject says what changed, body says why, no squashing, no tool trailers.
