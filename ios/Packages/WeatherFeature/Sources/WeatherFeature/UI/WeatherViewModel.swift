import DaybookPlatform
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.replicantstudio.daybook", category: "weather")
private let signposter = OSSignposter(logger: logger)

enum SelectedPlace: Equatable {
    case current
    case saved(SavedLocation)
}

@MainActor @Observable
final class WeatherViewModel {
    static let currentLocationName = "Current Location"

    private(set) var state: WeatherScreenState = .loading
    private(set) var isRefreshing = false
    private(set) var loadingAnnouncements = 0
    let locale: Locale

    private(set) var selectedPlace: SelectedPlace = .current
    private(set) var currentPlaceName: String?
    private(set) var savedLocations: [SavedLocation] = []
    private(set) var savedForecasts: [SavedLocation.ID: Forecast] = [:]
    private(set) var searchResults: [SavedLocation] = []
    var searchQuery = ""

    @ObservationIgnored private let store: any WeatherStore
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var resolvedPlace: LocatedPlace?
    @ObservationIgnored private var refreshTasks: [(place: SelectedPlace, task: Task<Void, Never>)] = []

    init(store: any WeatherStore, location: any LocationProviding, now: @escaping @Sendable () -> Date, locale: Locale) {
        self.store = store
        self.location = location
        self.now = now
        self.locale = locale
    }

    var currentDate: Date { now() }

    func start() async {
        await load(selectedPlace)
    }

    func allowLocation() async {
        let place: LocatedPlace
        do {
            place = try await location.current()
        } catch {
            show(error)
            return
        }
        await loadCurrent(knownPlace: place, announcesLoading: true)
    }

    func refresh() async {
        let place = selectedPlace
        if let inFlight = refreshTasks.first(where: { $0.place == place }) {
            await inFlight.task.value
            return
        }
        if place == .current, resolvedPlace == nil { return }
        let task = Task {
            await performRefresh(for: place)
            refreshTasks.removeAll { $0.place == place }
            updateIsRefreshing()
        }
        refreshTasks.append((place, task))
        updateIsRefreshing()
        await task.value
    }

    func retry() async {
        loadingAnnouncements += 1
        state = .loading
        switch selectedPlace {
        case .current: await loadCurrent(knownPlace: nil, announcesLoading: false)
        case .saved(let city): await loadSaved(city, announcesLoading: false)
        }
    }

    private func load(_ place: SelectedPlace) async {
        switch place {
        case .current:
            let authorization = await location.authorization()
            guard selectedPlace == .current else { return }
            switch authorization {
            case .notDetermined: state = .locationNotAsked
            case .denied: state = .locationDenied
            case .authorized: await loadCurrent(knownPlace: nil, announcesLoading: true)
            }
        case .saved(let city):
            await loadSaved(city, announcesLoading: true)
        }
    }

    private func loadCurrent(knownPlace: LocatedPlace?, announcesLoading: Bool) async {
        let place: LocatedPlace
        if let knownPlace {
            place = knownPlace
        } else {
            do {
                place = try await location.current()
            } catch {
                guard selectedPlace == .current else { return }
                show(error)
                return
            }
        }
        guard selectedPlace == .current else { return }
        resolvedPlace = place
        currentPlaceName = place.name
        await showCachedThenRefresh(
            for: .current,
            coordinate: place.coordinate,
            placeName: Self.placeName(of: place),
            announcesLoading: announcesLoading
        )
    }

    private func loadSaved(_ city: SavedLocation, announcesLoading: Bool) async {
        await showCachedThenRefresh(
            for: .saved(city),
            coordinate: city.coordinate,
            placeName: city.name,
            announcesLoading: announcesLoading
        )
    }

    private func showCachedThenRefresh(
        for place: SelectedPlace,
        coordinate: Coordinate,
        placeName: String,
        announcesLoading: Bool
    ) async {
        let interval = signposter.beginInterval("cachedForecast")
        let cached = await store.cachedForecast(for: coordinate)
        signposter.endInterval("cachedForecast", interval)
        guard selectedPlace == place else { return }

        if let cached {
            let isStale = cached.isStale(now: now())
            state = .loaded(cached, placeName: placeName, isOffline: isStale)
            if isStale { await refresh() }
        } else {
            if announcesLoading { loadingAnnouncements += 1 }
            state = .loading
            await refresh()
        }
    }

    private func performRefresh(for place: SelectedPlace) async {
        let coordinate: Coordinate
        let placeName: String
        switch place {
        case .current:
            let located: LocatedPlace
            do {
                located = try await location.current()
            } catch {
                guard selectedPlace == place else { return }
                if case .loaded = state { return }
                show(error)
                return
            }
            guard selectedPlace == place else { return }
            resolvedPlace = located
            currentPlaceName = located.name
            coordinate = located.coordinate
            placeName = Self.placeName(of: located)
        case .saved(let city):
            coordinate = city.coordinate
            placeName = city.name
        }

        let interval = signposter.beginInterval("refreshForecast")
        do {
            let fresh = try await store.refreshForecast(for: coordinate)
            signposter.endInterval("refreshForecast", interval)
            guard selectedPlace == place else { return }
            state = .loaded(fresh, placeName: placeName, isOffline: false)
        } catch {
            signposter.endInterval("refreshForecast", interval)
            logger.error("Forecast refresh failed: \(String(describing: error), privacy: .public)")
            guard selectedPlace == place else { return }
            if case .loaded(let forecast, let placeName, _) = state {
                state = .loaded(forecast, placeName: placeName, isOffline: true)
            } else {
                state = .failed(error)
            }
        }
    }

    private func updateIsRefreshing() {
        isRefreshing = refreshTasks.contains { $0.place == selectedPlace }
    }

    private func show(_ error: LocationError) {
        switch error {
        case .denied: state = .locationDenied
        case .unavailable: state = .failed(.notFound)
        }
    }

    private static func placeName(of place: LocatedPlace) -> String {
        place.name ?? currentLocationName
    }
}

extension WeatherViewModel {
    func loadSavedLocations() async {
        let locations = await store.savedLocations()
        var forecasts: [SavedLocation.ID: Forecast] = [:]
        for city in locations {
            forecasts[city.id] = await store.cachedForecast(for: city.coordinate)
        }
        savedLocations = locations
        savedForecasts = forecasts
    }

    func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        do {
            let results = try await store.searchPlaces(trimmed)
            guard !Task.isCancelled else { return }
            searchResults = results
        } catch {
            logger.error("Place search failed: \(String(describing: error), privacy: .public)")
            guard !Task.isCancelled else { return }
            searchResults = []
        }
    }

    func save(_ location: SavedLocation) async {
        await store.save(location)
        searchQuery = ""
        searchResults = []
        await loadSavedLocations()
    }

    func remove(id: SavedLocation.ID) async {
        await store.remove(id: id)
        await loadSavedLocations()
        if case .saved(let city) = selectedPlace, city.id == id {
            await select(.current)
        }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) async {
        let moving = fromOffsets.map { savedLocations[$0] }
        var reordered = savedLocations.enumerated()
            .filter { !fromOffsets.contains($0.offset) }
            .map(\.element)
        reordered.insert(contentsOf: moving, at: toOffset - fromOffsets.count(where: { $0 < toOffset }))
        savedLocations = reordered
        await store.reorder(reordered.map(\.id))
    }

    func select(_ place: SelectedPlace) async {
        selectedPlace = place
        updateIsRefreshing()
        await load(place)
    }
}
