import DaybookPlatform
import SnapshotTesting
import SwiftUI
import Testing
@testable import WeatherFeature

private let recordMode: SnapshotTestingConfiguration.Record =
    ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1" ? .all : .never

@Suite(.snapshots(record: recordMode), .serialized)
@MainActor
struct WeatherViewSnapshotTests {
    static let locale = Locale(identifier: "en_AT")
    static let now = Forecast.fixtureNow

    @Test func loadedDay() {
        assertSnapshot(
            of: screen(.loaded(.fixtureVienna, placeName: "Vienna", isOffline: false)),
            as: strategy()
        )
    }

    @Test func loadedNightOffline() {
        assertSnapshot(
            of: screen(.loaded(.fixtureToronto, placeName: "Toronto", isOffline: true)),
            as: strategy()
        )
    }

    @Test func loadedOfflineRecent() {
        assertSnapshot(
            of: screen(.loaded(.fixtureVienna, placeName: "Vienna", isOffline: true)),
            as: strategy()
        )
    }

    @Test func loadedAccessibility5() {
        assertSnapshot(
            of: screen(.loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
                .dynamicTypeSize(.accessibility5),
            as: strategy(height: 1600, contentSize: .accessibilityExtraExtraExtraLarge)
        )
    }

    @Test func loadedSavedCity() {
        assertSnapshot(
            of: screen(.loaded(.fixtureLisbon, placeName: "Lisbon", isOffline: false), isCurrentLocation: false),
            as: strategy()
        )
    }

    @Test func loadedDark() {
        assertSnapshot(
            of: screen(.loaded(.fixtureVienna, placeName: "Vienna", isOffline: false)),
            as: strategy(style: .dark)
        )
    }

    @Test func loading() {
        assertSnapshot(of: screen(.loading), as: strategy(precision: 0.99))
    }

    @Test func failedOffline() {
        assertSnapshot(of: screen(.failed(.offline)), as: strategy())
    }

    @Test func locationNotAsked() {
        assertSnapshot(of: screen(.locationNotAsked), as: strategy())
    }

    @Test func locationDenied() {
        assertSnapshot(of: screen(.locationDenied), as: strategy())
    }

    @Test func locationsWithItems() async {
        let viewModel = await locationsViewModel(
            cached: [SavedLocation.fixtures[0].coordinate: .fixtureLisbon],
            saved: SavedLocation.fixtures
        )

        assertSnapshot(of: locations(viewModel), as: strategy())
    }

    @Test func locationsDark() async {
        let viewModel = await locationsViewModel(
            cached: [SavedLocation.fixtures[0].coordinate: .fixtureLisbon],
            saved: SavedLocation.fixtures
        )

        assertSnapshot(of: locations(viewModel), as: strategy(style: .dark))
    }

    @Test func locationsAccessibility5() async {
        let viewModel = await locationsViewModel(
            cached: [SavedLocation.fixtures[0].coordinate: .fixtureLisbon],
            saved: SavedLocation.fixtures
        )

        assertSnapshot(
            of: locations(viewModel).dynamicTypeSize(.accessibility5),
            as: strategy(height: 1600, contentSize: .accessibilityExtraExtraExtraLarge)
        )
    }

    @Test func locationsEmpty() async {
        let viewModel = await locationsViewModel(cached: [:], saved: [])

        assertSnapshot(of: locations(viewModel), as: strategy())
    }

    @Test func locationsSearchResults() async {
        let oslo = SavedLocation.fixtures[1]
        let viewModel = await locationsViewModel(cached: [:], saved: [], searchResults: [oslo])
        viewModel.searchQuery = "o"
        await viewModel.search("o")

        assertSnapshot(of: locations(viewModel), as: strategy())
    }

    private func locationsViewModel(
        cached: [Coordinate: Forecast],
        saved: [SavedLocation],
        searchResults: [SavedLocation]? = nil
    ) async -> WeatherViewModel {
        let vienna = LocatedPlace(coordinate: Coordinate(latitude: 48.2082, longitude: 16.3738), name: "Vienna")
        var cached = cached
        cached[vienna.coordinate] = .fixtureVienna
        let store = FakeWeatherStore(cached: cached, saved: saved)
        if let searchResults {
            await store.enqueueSearch(.success(searchResults))
        }
        let viewModel = WeatherViewModel(
            store: store,
            location: FakeLocation(authorization: .authorized, current: [.success(vienna)]),
            now: TestClock(Self.now).closure,
            locale: Self.locale
        )
        await viewModel.start()
        await viewModel.loadSavedLocations()
        return viewModel
    }

    private func locations(_ viewModel: WeatherViewModel) -> some View {
        LocationsView(viewModel: viewModel, onDone: {})
            .environment(\.theme, .standard)
            .environment(\.timeZone, TimeZone(identifier: "Europe/Vienna")!)
            .transaction { $0.animation = nil }
    }

    private func screen(_ state: WeatherScreenState, isCurrentLocation: Bool = true) -> some View {
        WeatherView(state: state, now: Self.now, locale: Self.locale, isCurrentLocation: isCurrentLocation)
            .environment(\.theme, .standard)
            .environment(\.timeZone, TimeZone(identifier: "Europe/Vienna")!)
            .transaction { $0.animation = nil }
    }

    private func strategy<V: View>(
        height: CGFloat = 852,
        contentSize: UIContentSizeCategory = .large,
        precision: Float = 1,
        style: UIUserInterfaceStyle = .light
    ) -> Snapshotting<V, UIImage> {
        .image(
            precision: precision,
            perceptualPrecision: 0.98,
            layout: .fixed(width: 393, height: height),
            traits: UITraitCollection { mutable in
                mutable.displayScale = 2
                mutable.userInterfaceStyle = style
                mutable.preferredContentSizeCategory = contentSize
                mutable.legibilityWeight = .regular
                mutable.accessibilityContrast = .normal
            }
        )
    }
}
