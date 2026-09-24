import DaybookPlatform
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.replicantstudio.daybook", category: "weather")
private let signposter = OSSignposter(logger: logger)

@MainActor @Observable
final class WeatherViewModel {
    static let currentLocationName = "Current Location"

    private(set) var state: WeatherScreenState = .loading
    private(set) var isRefreshing = false
    private(set) var loadingAnnouncements = 0
    let locale: Locale

    @ObservationIgnored private let store: any WeatherStore
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var resolvedPlace: LocatedPlace?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(store: any WeatherStore, location: any LocationProviding, now: @escaping @Sendable () -> Date, locale: Locale) {
        self.store = store
        self.location = location
        self.now = now
        self.locale = locale
    }

    var currentDate: Date { now() }

    func start() async {
        switch await location.authorization() {
        case .notDetermined: state = .locationNotAsked
        case .denied: state = .locationDenied
        case .authorized: await loadCurrent(knownPlace: nil, announcesLoading: true)
        }
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
        if let refreshTask {
            await refreshTask.value
            return
        }
        guard resolvedPlace != nil else { return }
        let task = Task {
            await performRefresh()
            refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    func retry() async {
        loadingAnnouncements += 1
        state = .loading
        await loadCurrent(knownPlace: nil, announcesLoading: false)
    }

    private func loadCurrent(knownPlace: LocatedPlace?, announcesLoading: Bool) async {
        let place: LocatedPlace
        if let knownPlace {
            place = knownPlace
        } else {
            do {
                place = try await location.current()
            } catch {
                show(error)
                return
            }
        }
        resolvedPlace = place

        let interval = signposter.beginInterval("cachedForecast")
        let cached = await store.cachedForecast(for: place.coordinate)
        signposter.endInterval("cachedForecast", interval)

        if let cached {
            let isStale = cached.isStale(now: now())
            state = .loaded(cached, placeName: Self.placeName(of: place), isOffline: isStale)
            if isStale { await refresh() }
        } else {
            if announcesLoading { loadingAnnouncements += 1 }
            state = .loading
            await refresh()
        }
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let place: LocatedPlace
        do {
            place = try await location.current()
        } catch {
            if case .loaded = state { return }
            show(error)
            return
        }
        resolvedPlace = place

        let interval = signposter.beginInterval("refreshForecast")
        do {
            let fresh = try await store.refreshForecast(for: place.coordinate)
            signposter.endInterval("refreshForecast", interval)
            state = .loaded(fresh, placeName: Self.placeName(of: place), isOffline: false)
        } catch {
            signposter.endInterval("refreshForecast", interval)
            logger.error("Forecast refresh failed: \(String(describing: error), privacy: .public)")
            if case .loaded(let forecast, let placeName, _) = state {
                state = .loaded(forecast, placeName: placeName, isOffline: true)
            } else {
                state = .failed(error)
            }
        }
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
