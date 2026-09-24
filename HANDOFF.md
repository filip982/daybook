# Handoff

Written 2026-09-22 for whoever continues this repo with no chat history. Everything below is verifiable from git, the docs folder and GitHub.

## 1. Goal

Daybook is a personal daily app built natively four times (SwiftUI, Kotlin/Compose, React Native, Flutter) over a shared Rust core, as a public showcase. Phase 1 is the Weather tab on iOS, shipped to TestFlight. The binding design is `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`; section 12 lists the build order.

All six build steps of Phase 1 are done. Phase 1b (Rust core) is on hold by the owner's decision; do not start it.

The last session (2026-09-20) built step 6, the TestFlight release pipeline, and shipped the first build, `0.1.0 (48)`, which shows a placeholder screen. The next build shows real weather, from step 5.

## 2. What is done

Per-step plans are in `docs/superpowers/plans/` and were executed task by task; each task is one commit on `develop` with a body that says why.

| Step | Commit range | What exists now |
|---|---|---|
| 1 Project and CI | up to `ios.yml` | XcodeGen project (`ios/project.yml`), packages `DaybookPlatform` and `WeatherFeature`, `Makefile`, layer lint, GitHub Actions test job |
| 2 Static screen | | `Model/` (Forecast, WeatherCode, DaySummary, SavedLocation, WeatherError), `UI/` (WeatherView with all states, components, formatter, theme), snapshot tests |
| 3 Open-Meteo | | `Providers/OpenMeteoProvider.swift` and mappings, recorded fixtures, per-test URL stubs, nightly live schema check (`ios-live.yml`) |
| 4 Store and cache | up to `905a72e` | `Store/LiveWeatherStore.swift`, `FileForecastCache`, `SavedLocationsFile`, contract tests, `FixtureProvider` (DEBUG), pinned clock via `LiveWeatherStore.clock(arguments:)` |
| 6 Release pipeline | `2a4520c`..`459dd57` | app icon, `scripts/release-info.sh`, `scripts/tag-release.sh`, `make ios-archive / ios-verify-archive / ios-upload`, `ios/ExportOptions.plist`, `release` job in `.github/workflows/ios.yml` |

Layout of the feature package (one target, folders as layers; `UI/` must never name a `Providers/` type, enforced by `make lint`):

```
ios/Packages/WeatherFeature/Sources/WeatherFeature/
  Model/      Forecast, WeatherCode, DaySummary, SavedLocation, WeatherError, WeatherStore protocol
  Providers/  WeatherProvider protocol, OpenMeteoProvider, FixtureProvider (#if DEBUG)
  Store/      LiveWeatherStore (actor), FileForecastCache, SavedLocationsFile, LiveWeatherStore+Live (factory + clock)
  UI/         WeatherTab (the only public type), WeatherView, WeatherScreenState, Components/
ios/Packages/DaybookPlatform/Sources/DaybookPlatform/
  Foundation/ Coordinate, LocationProviding protocol, LocationError, LocatedPlace
  Theme/      Theme, contrast helpers
```

Decisions that shape step 5, and why:

- Pure Swift first, Rust later (Phase 1b), so git history shows the progress. Rust is on hold until the owner says go.
- One SPM package per tab with one target and folders inside. No UI/Domain/Data package split; the owner does not want import churn.
- Vanilla initializer injection, no DI library, no TCA. Defaults are allowed only for pure values, never for live network or clocks.
- Weather sources sit behind `WeatherProvider`; a second provider (MET Norway) is deferred.
- The store is called `WeatherStore` (not Repository); the fetch layer is called `provider` (not DataSource).
- Time: the forecast carries its own `TimeZone`, Open-Meteo is called with `timeformat=unixtime`, all labels are formatted in the forecast's zone. Never `Date()`, `Locale.current` or `TimeZone.current` in Model, formatter, provider or store code; the clock is injected.
- Units: metric in the model, `Measurement` only in the formatter, `UnitTemperature(forLocale:usage:.weather)`.
- Accessibility is part of "done": Dynamic Type, one VoiceOver element per day, 4.5:1 contrast checked in `ThemeTests`.
- Tests: Swift Testing, about 200 tests in `WeatherFeatureTests`, `swift-snapshot-testing` 1.19.5 is the only third-party dependency (test target only). Contract tests are written only against `any WeatherStore` so they survive Phase 1b.
- CI/CD: GitHub Actions only, no fastlane, no Xcode Cloud. Xcode 26.5 / Swift 6.3.2 pinned, simulator `iPhone 17, OS 26.5`, runner `macos-26`.
- Release: unsigned archive, cloud-managed signing at `-exportArchive` only (a signed archive on a fresh runner mints a development certificate per run until Apple's cap). Version comes from the tag, build number is the commit count at the tagged commit. Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` live only in the GitHub environment `testflight` (required reviewer: the owner, tag rule `v*`).
- Branches: all work goes directly on `develop`, one commit per task, subject says what, body says why, no squashing, **no `Co-Authored-By` trailers**. `main` is only for tags and releases.
- Bundle id `com.replicantstudio.daybook`, team `KTS29DB5CZ`, App Store name "Daybook – Daily Companion" (plain "Daybook" was taken), SKU `daybook-ios`. License MIT © 2026 Replicant Studio.

## 3. In progress

Nothing is half-finished in the code. `develop` is clean and equal to `origin/develop` at `459dd57`. `main` is at `3e3abea`, tagged `v0.1.0`.

Known leftovers, none blocking:

- HTTP 429 maps to `.server`; no retry or backoff exists.
- The app icon is a generated placeholder (blue gradient, sun, two lines); the generator script is in the step 6 plan, Task 1, not in the repo.
- The `test` job re-runs on every tag (`needs: test`), about 15 minutes per release. Kept because the spec requires it.
- The plan Artifact page on claude.ai from the planning session is stale; the repo is the source of truth.
- This machine now has Xcode 26.6 at `/Applications/Xcode_26.6.app` and Xcode 27.0 at `/Applications/Xcode.app`; `xcode-select` points at CommandLineTools. Use `DEVELOPER_DIR=/Applications/Xcode_26.6.app`. CI still pins 26.5.
- `WeatherError.notFound` is now produced for `LocationError.unavailable`; its copy "No forecast for this place" is a known wording gap.
- `swift-snapshot-testing` does not draw the iOS 26 toolbar/search glass, so `locationsDark` shows no Done button and light locations snapshots show a faint Search placeholder; the smoke test asserts the Done button instead.

## 4. Next steps, in order

1. Push `develop` and watch CI.
2. Run on a real iPhone for the permission flow.
3. Release `0.2.0` with `scripts/tag-release.sh`.

## 5. Open questions, gotchas, failed attempts

Open questions for the owner:

- Whether to save the "one commit per logical step, what + why, no squash" rule into the global `~/.claude/CLAUDE.md`. Not done; the practice is followed anyway.
- Sky colour on clear days is a deeper blue than the mockup because of the 4.5:1 contrast rule; the alternative is a text scrim. Range-bar hues are relative to the ten-day span. Both are design notes, not bugs.
- Phase 1b open decision: HTTP inside Rust versus a native HTTP port per platform. Only relevant when Rust starts.

Gotchas that cost time:

- GitHub Actions runs `run:` steps without an explicit shell as `bash -e`, **without pipefail**. `ios.yml` sets `defaults.run.shell: bash` for that reason. A plan and a reviewer both asserted the opposite; check tool-behaviour claims against docs.
- With pipefail on, `xcodebuild -version | grep -q` fails: `grep -q` closes the pipe early and xcodebuild aborts. Use plain `grep`.
- `actions/checkout` with `fetch-depth: 0` does fetch `refs/remotes/origin/*`; a reviewer claimed `origin/main` would be missing. It is present, and `release-info.sh` relies on it.
- Xcode on this machine is 26.5 (17F42) at `/Applications/Xcode.app`; an `Xcode_27.app` is also installed. The spec once said 26.6 from a stale reading. Re-check `xcodebuild -version` before pinning anything.
- Swift Testing runs tests in parallel in one process: network stubs use a per-session key in an `X-Stub-Key` header and a lock-protected table (`Tests/.../Support/StubURLProtocol.swift`). Never add a static shared handler.
- Wall-clock date parsing collapsed DST hours in step 3; the provider now requests `timeformat=unixtime`. Keep it.
- Snapshot tests are recorded only when `SNAPSHOT_RECORD=1` (`make ios-snapshots-record`, passed as `TEST_RUNNER_SNAPSHOT_RECORD=1`); traits pin display scale, content size, legibility weight and contrast.
- Subagents sometimes add a `Co-Authored-By` trailer; check `git log -1 --format=%B` and amend.
- TestFlight first-run trap: an internal tester tied to an old expired Apple team showed "No Builds Available" and the accept link said "membership has expired". Removing and re-adding the tester fixed it. The account holder's Apple ID needs no invite.
- The store name "Daybook" is taken on the App Store, hence the suffixed name in App Store Connect. Nothing in the repo references the store name.
- Open-Meteo: data is CC BY 4.0 (attribution required in the app before any public release), free tier is non-commercial. TestFlight only for now is the owner's decision.

Tried and dropped:

- Renaming Provider to DataSource: reverted at the owner's request.
- Splitting `WeatherFeature` into UI/Domain/Data targets: rejected by the owner.
- Signed archive with API key flags on both `xcodebuild` calls (as the spec first said): replaced by the unsigned archive to avoid the certificate cap; the spec was amended in `5f09625`.

## 6. Commands and environment

Requirements: macOS with `DEVELOPER_DIR=/Applications/Xcode_26.6.app` set for every xcodebuild/make/xcrun command (CI still pins 26.5; `xcode-select` on this machine points at CommandLineTools), `brew install xcodegen` (2.45.4), `gh` authenticated for `filip982/daybook`, simulator "iPhone 17" with iOS 26.5.

```bash
export DEVELOPER_DIR=/Applications/Xcode_26.6.app
make                       # lint + script tests + package tests + app build + bundle check (default goal)
make lint                  # layer rule and its self-test
make scripts-test          # release-info.sh and tag-release.sh in throwaway repos
make ios-test              # DaybookPlatform + WeatherFeature test suites on the simulator
make ios-snapshots-record  # re-record snapshot PNGs, then commit them on purpose
make ios-test-live         # live Open-Meteo schema check (network)
make project               # regenerate ios/Daybook.xcodeproj (git-ignored)
make ios-build             # Debug simulator build to ios/build/DerivedData
make ios-archive ios-verify-archive VERSION=0.2.0 BUILD=7   # unsigned Release archive + checks, local only
scripts/tag-release.sh 0.2.0                                 # annotated tag on main with a commit summary; prints the push command
gh run list --branch develop --limit 3 && gh run watch <id>  # CI
```

Never run `make ios-upload` locally; it needs the App Store Connect key, which exists only in the GitHub environment. Never commit `ios/Daybook.xcodeproj`, `ios/App/Info.plist`, `ios/build/` or any `.p8`; all are git-ignored.

Related process files: `~/.claude/skills/new-client/playbook.md` (cross-project lessons, two lines from this project), Second Brain records `20260919-daybook-phase-1-weather-ios-architecture-a2a216` and `20260920-daybook-ios-0-1-0-48-uploaded-to-testfli-46b458`.
