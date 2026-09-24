import DaybookPlatform

actor FakeLocation: LocationProviding {
    private var authorizationValue: LocationAuthorization
    private var results: [Result<LocatedPlace, LocationError>]

    private(set) var currentCalls = 0

    init(authorization: LocationAuthorization, current: [Result<LocatedPlace, LocationError>]) {
        authorizationValue = authorization
        results = current
    }

    func setAuthorization(_ authorization: LocationAuthorization) {
        authorizationValue = authorization
    }

    func authorization() async -> LocationAuthorization {
        authorizationValue
    }

    func current() async throws(LocationError) -> LocatedPlace {
        currentCalls += 1
        let result = results.count > 1 ? results.removeFirst() : results[0]
        switch result {
        case .success(let place): return place
        case .failure(let error): throw error
        }
    }
}
