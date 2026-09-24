#if DEBUG
import DaybookPlatform
import Foundation
import Testing
@testable import WeatherFeature

private let vienna = LocatedPlace(coordinate: Coordinate(latitude: 48.2082, longitude: 16.3738), name: "Vienna")
private let lisbon = SavedLocation.fixtures[0]
private let oslo = SavedLocation.fixtures[1]
private let toronto = SavedLocation.fixtures[2]

@MainActor
private struct Harness {
    let store: FakeWeatherStore
    let location: FakeLocation
    let viewModel: WeatherViewModel

    init(
        authorization: LocationAuthorization = .authorized,
        cached: [Coordinate: Forecast] = [:],
        saved: [SavedLocation] = SavedLocation.fixtures
    ) {
        let store = FakeWeatherStore(cached: cached, saved: saved)
        let location = FakeLocation(authorization: authorization, current: [.success(vienna)])
        self.store = store
        self.location = location
        viewModel = WeatherViewModel(
            store: store,
            location: location,
            now: TestClock(Forecast.fixtureNow).closure,
            locale: Locale(identifier: "en_AT")
        )
    }
}

@Suite @MainActor struct WeatherViewModelLocationsTests {
    @Test func loadSavedLocationsKeepsTheStoreOrderAndOnlyCachedForecasts() async {
        let harness = Harness(cached: [lisbon.coordinate: .fixtureLisbon])

        await harness.viewModel.loadSavedLocations()

        #expect(harness.viewModel.savedLocations == [lisbon, oslo, toronto])
        #expect(harness.viewModel.savedForecasts == [lisbon.id: .fixtureLisbon])
    }

    @Test func searchSkipsBlankQueriesAndSwallowsErrors() async {
        let harness = Harness()
        await harness.store.enqueueSearch(.success([lisbon]))
        await harness.store.enqueueSearch(.failure(.offline))

        await harness.viewModel.search("   ")
        #expect(harness.viewModel.searchResults.isEmpty)
        #expect(await harness.store.searchCalls.isEmpty)

        await harness.viewModel.search("Lis")
        #expect(harness.viewModel.searchResults == [lisbon])

        await harness.viewModel.search("Lis")
        #expect(harness.viewModel.searchResults.isEmpty)
        #expect(await harness.store.searchCalls == ["Lis", "Lis"])
    }

    @Test func saveStoresTheCityAndClearsTheSearch() async {
        let harness = Harness(saved: [])
        await harness.store.enqueueSearch(.success([lisbon]))
        harness.viewModel.searchQuery = "Lis"
        await harness.viewModel.search("Lis")

        await harness.viewModel.save(lisbon)

        #expect(await harness.store.savedLocations() == [lisbon])
        #expect(harness.viewModel.savedLocations.last == lisbon)
        #expect(harness.viewModel.searchQuery == "")
        #expect(harness.viewModel.searchResults.isEmpty)

        await harness.viewModel.save(lisbon)

        #expect(await harness.store.savedLocations() == [lisbon])
        #expect(harness.viewModel.savedLocations == [lisbon])
    }

    @Test func removingTheSelectedCitySelectsCurrentLocation() async {
        let harness = Harness(cached: [lisbon.coordinate: .fixtureLisbon, vienna.coordinate: .fixtureVienna])
        await harness.viewModel.loadSavedLocations()
        await harness.viewModel.select(.saved(lisbon))

        await harness.viewModel.remove(id: lisbon.id)

        #expect(await harness.store.savedLocations() == [oslo, toronto])
        #expect(harness.viewModel.savedLocations == [oslo, toronto])
        #expect(harness.viewModel.selectedPlace == .current)
        #expect(harness.viewModel.state == .loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
    }

    @Test func moveReordersLocallyAndInTheStore() async {
        let harness = Harness()
        await harness.viewModel.loadSavedLocations()

        await harness.viewModel.move(fromOffsets: [0], toOffset: 3)

        #expect(await harness.store.reorderCalls.last == [oslo.id, toronto.id, lisbon.id])
        #expect(harness.viewModel.savedLocations == [oslo, toronto, lisbon])
    }

    @Test func selectingASavedCityWithAFreshCacheSkipsRefreshAndLocation() async {
        let harness = Harness(cached: [lisbon.coordinate: .fixtureLisbon])

        await harness.viewModel.select(.saved(lisbon))

        #expect(harness.viewModel.state == .loaded(.fixtureLisbon, placeName: "Lisbon", isOffline: false))
        #expect(await harness.store.refreshCalls.isEmpty)
        #expect(await harness.location.currentCalls == 0)
    }

    @Test func selectingASavedCityWithoutACacheLoadsIt() async {
        let harness = Harness()
        await harness.store.enqueueRefresh(.success(.fixtureOslo))
        await harness.store.holdNextRefresh()

        let select = Task { await harness.viewModel.select(.saved(oslo)) }
        await harness.store.waitUntilRefreshBegan()

        #expect(harness.viewModel.state == .loading)
        #expect(harness.viewModel.loadingAnnouncements == 1)
        #expect(await harness.store.refreshCalls.last == oslo.coordinate)

        await harness.store.releaseRefresh()
        await select.value

        #expect(harness.viewModel.state == .loaded(.fixtureOslo, placeName: "Oslo", isOffline: false))
    }

    @Test func aLateResultForAnUnselectedPlaceIsDropped() async {
        let harness = Harness(cached: [lisbon.coordinate: .fixtureLisbon])
        await harness.store.enqueueRefresh(.success(.fixtureVienna))
        await harness.store.holdNextRefresh()
        let start = Task { await harness.viewModel.start() }
        await harness.store.waitUntilRefreshBegan()

        await harness.viewModel.select(.saved(lisbon))
        #expect(harness.viewModel.state == .loaded(.fixtureLisbon, placeName: "Lisbon", isOffline: false))

        await harness.store.releaseRefresh()
        await start.value

        #expect(harness.viewModel.state == .loaded(.fixtureLisbon, placeName: "Lisbon", isOffline: false))
        #expect(harness.viewModel.isRefreshing == false)
    }

    @Test func aRefreshForAnotherPlaceDoesNotJoinTheInFlightOne() async {
        let harness = Harness()
        await harness.store.enqueueRefresh(.success(.fixtureOslo))
        await harness.store.enqueueRefresh(.success(.fixtureVienna))
        await harness.store.holdNextRefresh()
        let start = Task { await harness.viewModel.start() }
        await harness.store.waitUntilRefreshBegan()

        await harness.viewModel.select(.saved(oslo))

        #expect(await harness.store.refreshCalls == [vienna.coordinate, oslo.coordinate])
        #expect(harness.viewModel.state == .loaded(.fixtureOslo, placeName: "Oslo", isOffline: false))

        await harness.store.releaseRefresh()
        await start.value

        #expect(harness.viewModel.state == .loaded(.fixtureOslo, placeName: "Oslo", isOffline: false))
    }

    @Test func selectingCurrentLocationWhenDeniedShowsLocationDenied() async {
        let harness = Harness(authorization: .denied, cached: [lisbon.coordinate: .fixtureLisbon])
        await harness.viewModel.select(.saved(lisbon))

        await harness.viewModel.select(.current)

        #expect(harness.viewModel.selectedPlace == .current)
        #expect(harness.viewModel.state == .locationDenied)
    }
}
#endif
