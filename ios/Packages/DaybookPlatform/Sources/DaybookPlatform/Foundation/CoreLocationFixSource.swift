import CoreLocation

struct CoreLocationFixSource: LocationFixSource {
    init() {}

    func authorization() async -> LocationAuthorization {
        await AuthorizationObserver.shared.authorization
    }

    func fix() async throws(LocationError) -> Coordinate {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location {
                    return Coordinate(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    throw LocationError.denied
                }
            }
        } catch let error as LocationError {
            throw error
        } catch {
            throw .unavailable
        }
        throw .unavailable
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        return placemark.locality ?? placemark.name
    }
}

@MainActor
private final class AuthorizationObserver: NSObject, CLLocationManagerDelegate {
    static let shared = AuthorizationObserver()

    private let manager = CLLocationManager()

    var authorization: LocationAuthorization {
        LocationAuthorization(manager.authorizationStatus)
    }

    override private init() {
        super.init()
        manager.delegate = self
    }
}

extension LocationAuthorization {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied, .restricted: self = .denied
        case .authorizedWhenInUse, .authorizedAlways: self = .authorized
        @unknown default: self = .denied
        }
    }
}
