#if DEBUG
import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

private let vienna = LocatedPlace(coordinate: Coordinate(latitude: 48.2082, longitude: 16.3738), name: "Vienna")

private func refetched(_ forecast: Forecast, at date: Date) -> Forecast {
    Forecast(
        timeZone: forecast.timeZone,
        current: forecast.current,
        hourly: forecast.hourly,
        daily: forecast.daily,
        fetchedAt: date
    )
}

@MainActor
private struct Harness {
    let store: FakeWeatherStore
    let location: FakeLocation
    let clock: TestClock
    let viewModel: WeatherViewModel

    init(
        authorization: LocationAuthorization = .authorized,
        current: [Result<LocatedPlace, LocationError>] = [.success(vienna)],
        cached: [Coordinate: Forecast] = [:],
        secondsAfterFixtureNow: TimeInterval = 0
    ) {
        let store = FakeWeatherStore(cached: cached, saved: [])
        let location = FakeLocation(authorization: authorization, current: current)
        let clock = TestClock(Forecast.fixtureNow.addingTimeInterval(secondsAfterFixtureNow))
        self.store = store
        self.location = location
        self.clock = clock
        viewModel = WeatherViewModel(
            store: store,
            location: location,
            now: clock.closure,
            locale: Locale(identifier: "en_AT")
        )
    }
}

@Suite @MainActor struct WeatherViewModelTests {
    @Test func startsLoadingWithNothingAnnounced() {
        let harness = Harness()

        #expect(harness.viewModel.state == .loading)
        #expect(harness.viewModel.isRefreshing == false)
        #expect(harness.viewModel.loadingAnnouncements == 0)
    }

    @Test func notDeterminedShowsLocationNotAskedWithoutLocationOrStoreCalls() async {
        let harness = Harness(authorization: .notDetermined)

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .locationNotAsked)
        #expect(await harness.location.currentCalls == 0)
        #expect(await harness.store.cachedCalls.isEmpty)
        #expect(await harness.store.refreshCalls.isEmpty)
    }

    @Test func deniedShowsLocationDeniedWithoutStoreCalls() async {
        let harness = Harness(authorization: .denied)

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .locationDenied)
        #expect(await harness.store.cachedCalls.isEmpty)
        #expect(await harness.store.refreshCalls.isEmpty)
    }

    @Test func freshCacheIsShownWithoutARefresh() async {
        let harness = Harness(cached: [vienna.coordinate: .fixtureVienna])

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
        #expect(await harness.store.refreshCalls.isEmpty)
        #expect(harness.viewModel.loadingAnnouncements == 0)
    }

    @Test func staleCacheIsShownOfflineWhileTheRefreshRuns() async {
        let harness = Harness(cached: [vienna.coordinate: .fixtureVienna], secondsAfterFixtureNow: 26 * 60)
        let fresh = refetched(.fixtureVienna, at: harness.clock.now)
        await harness.store.enqueueRefresh(.success(fresh))
        await harness.store.holdNextRefresh()

        let start = Task { await harness.viewModel.start() }
        await harness.store.waitUntilRefreshBegan()

        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: true))
        #expect(harness.viewModel.isRefreshing == true)

        await harness.store.releaseRefresh()
        await start.value

        #expect(harness.viewModel.state == .loaded(fresh, placeName: "Vienna", isOffline: false))
        #expect(harness.viewModel.isRefreshing == false)
    }

    @Test func noCacheAnnouncesLoadingOnceWhileTheRefreshRuns() async {
        let harness = Harness()
        await harness.store.enqueueRefresh(.success(.fixtureVienna))
        await harness.store.holdNextRefresh()

        let start = Task { await harness.viewModel.start() }
        await harness.store.waitUntilRefreshBegan()

        #expect(harness.viewModel.state == .loading)
        #expect(harness.viewModel.loadingAnnouncements == 1)

        await harness.store.releaseRefresh()
        await start.value

        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
        #expect(harness.viewModel.loadingAnnouncements == 1)
    }

    @Test func noCacheAndAFailedRefreshShowsTheError() async {
        let harness = Harness()
        await harness.store.enqueueRefresh(.failure(.offline))

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .failed(.offline))
    }

    @Test func staleCacheAndAFailedRefreshKeepsTheCacheOffline() async {
        let harness = Harness(cached: [vienna.coordinate: .fixtureVienna], secondsAfterFixtureNow: 26 * 60)
        await harness.store.enqueueRefresh(.failure(.server))

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: true))
    }

    @Test func failedPullToRefreshOnAFreshCacheMarksItOfflineWithoutAnnouncing() async {
        let harness = Harness(cached: [vienna.coordinate: .fixtureVienna])
        await harness.viewModel.start()
        await harness.store.enqueueRefresh(.failure(.offline))

        await harness.viewModel.refresh()

        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: true))
        #expect(harness.viewModel.loadingAnnouncements == 0)
    }

    @Test func concurrentRefreshesShareOneRequest() async {
        let harness = Harness(cached: [vienna.coordinate: .fixtureVienna])
        await harness.viewModel.start()
        await harness.store.enqueueRefresh(.success(.fixtureVienna))
        await harness.store.holdNextRefresh()

        let first = Task { await harness.viewModel.refresh() }
        let second = Task { await harness.viewModel.refresh() }
        await harness.store.waitUntilRefreshBegan()
        await harness.store.releaseRefresh()
        await first.value
        await second.value

        #expect(await harness.store.refreshCalls.count == 1)
        #expect(harness.viewModel.isRefreshing == false)
    }

    @Test func aRefreshAfterTheLastOneFinishedIssuesANewRequest() async {
        let harness = Harness(cached: [vienna.coordinate: .fixtureVienna])
        await harness.viewModel.start()
        await harness.store.enqueueRefresh(.success(.fixtureVienna))
        await harness.store.enqueueRefresh(.success(.fixtureVienna))

        await harness.viewModel.refresh()
        await harness.viewModel.refresh()

        #expect(await harness.store.refreshCalls.count == 2)
    }

    @Test func refreshBeforeAPlaceIsResolvedDoesNothing() async {
        let harness = Harness(authorization: .notDetermined)
        await harness.viewModel.start()

        await harness.viewModel.refresh()

        #expect(harness.viewModel.state == .locationNotAsked)
        #expect(await harness.store.refreshCalls.isEmpty)
        #expect(await harness.store.cachedCalls.isEmpty)
    }

    @Test func allowLocationLoadsTheResolvedPlace() async {
        let harness = Harness(authorization: .notDetermined, cached: [vienna.coordinate: .fixtureVienna])
        await harness.viewModel.start()

        await harness.viewModel.allowLocation()

        #expect(await harness.location.currentCalls == 1)
        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
    }

    @Test func allowLocationDeniedShowsLocationDenied() async {
        let harness = Harness(authorization: .notDetermined, current: [.failure(.denied)])
        await harness.viewModel.start()

        await harness.viewModel.allowLocation()

        #expect(harness.viewModel.state == .locationDenied)
    }

    @Test func unavailableLocationDuringStartShowsNotFound() async {
        let harness = Harness(current: [.failure(.unavailable)])

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .failed(.notFound))
    }

    @Test func retryAnnouncesLoadingAndLoads() async {
        let harness = Harness()
        await harness.store.enqueueRefresh(.failure(.offline))
        await harness.viewModel.start()
        #expect(harness.viewModel.state == .failed(.offline))
        #expect(harness.viewModel.loadingAnnouncements == 1)
        await harness.store.enqueueRefresh(.success(.fixtureVienna))

        await harness.viewModel.retry()

        #expect(harness.viewModel.loadingAnnouncements == 2)
        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
    }

    @Test func unnamedPlaceUsesTheCurrentLocationName() async {
        let unnamed = LocatedPlace(coordinate: vienna.coordinate, name: nil)
        let harness = Harness(current: [.success(unnamed)], cached: [vienna.coordinate: .fixtureVienna])

        await harness.viewModel.start()

        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Current Location", isOffline: false))
        #expect(WeatherViewModel.currentLocationName == "Current Location")
    }

    @Test func theStoreReceivesTheLocationsCoordinate() async {
        let harness = Harness()
        await harness.store.enqueueRefresh(.success(.fixtureVienna))

        await harness.viewModel.start()

        #expect(await harness.store.cachedCalls == [vienna.coordinate])
        #expect(await harness.store.refreshCalls == [vienna.coordinate])
    }

    @Test func stalenessFollowsTheInjectedClock() async {
        let fresh = Harness(cached: [vienna.coordinate: .fixtureVienna], secondsAfterFixtureNow: 24 * 60)
        await fresh.viewModel.start()
        #expect(await fresh.store.refreshCalls.isEmpty)

        let stale = Harness(cached: [vienna.coordinate: .fixtureVienna], secondsAfterFixtureNow: 26 * 60)
        await stale.store.enqueueRefresh(.success(.fixtureVienna))
        await stale.viewModel.start()
        #expect(await stale.store.refreshCalls.count == 1)
    }
}
#endif
