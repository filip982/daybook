import CoreLocation
import Foundation
import Testing
@testable import DaybookPlatform

@Suite struct LocationServiceTests {
    private let vienna = Coordinate(latitude: 48.2082, longitude: 16.3738)
    private let oslo = Coordinate(latitude: 59.9127, longitude: 10.7461)
    private let clock = TestClock(Date(timeIntervalSince1970: 1_758_300_000))

    private func makeService(_ source: FakeLocationFixSource) -> LocationService {
        LocationService(source: source, now: clock.closure)
    }

    private func letCallersJoinTheHeldFix() async {
        for _ in 0..<100 { await Task.yield() }
    }

    @Test(arguments: [LocationAuthorization.notDetermined, .denied, .authorized])
    func authorizationForwardsTheSourceValue(_ authorization: LocationAuthorization) async {
        let service = makeService(FakeLocationFixSource(authorization: authorization))
        #expect(await service.authorization() == authorization)
    }

    @Test(arguments: zip(
        [CLAuthorizationStatus.notDetermined, .denied, .restricted, .authorizedWhenInUse, .authorizedAlways],
        [LocationAuthorization.notDetermined, .denied, .denied, .authorized, .authorized]
    ))
    func mapsCoreLocationStatus(_ status: CLAuthorizationStatus, _ expected: LocationAuthorization) {
        #expect(LocationAuthorization(status) == expected)
    }

    @Test func concurrentCallersShareOneFix() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.success(vienna))
        await source.setPlaceName("Vienna", for: vienna)
        await source.holdNextFix()
        let service = makeService(source)

        async let first = service.current()
        async let second = service.current()
        async let third = service.current()
        await source.waitUntilFixBegan()
        await letCallersJoinTheHeldFix()
        await source.releaseFix()

        let places = try await [first, second, third]
        let expected = LocatedPlace(coordinate: vienna, name: "Vienna")
        #expect(places == [expected, expected, expected])
        #expect(await source.fixCalls == 1)
    }

    @Test func reusesTheFixWithinTheInterval() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.success(vienna))
        await source.enqueueFix(.success(oslo))
        let service = makeService(source)

        let first = try await service.current()
        clock.advance(by: 59)
        let second = try await service.current()

        #expect(second == first)
        #expect(await source.fixCalls == 1)
    }

    @Test func fetchesAgainAtExactlyTheInterval() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.success(vienna))
        await source.enqueueFix(.success(oslo))
        let service = makeService(source)

        _ = try await service.current()
        clock.advance(by: 60)
        let second = try await service.current()

        #expect(second.coordinate == oslo)
        #expect(await source.fixCalls == 2)
    }

    @Test(arguments: [LocationError.denied, .unavailable])
    func throwsTheSourceError(_ error: LocationError) async {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.failure(error))
        let service = makeService(source)

        await #expect(throws: error) { try await service.current() }
    }

    @Test func failedFetchDoesNotPoisonTheNextCall() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.failure(.unavailable))
        await source.enqueueFix(.success(vienna))
        let service = makeService(source)

        await #expect(throws: LocationError.unavailable) { try await service.current() }
        let place = try await service.current()

        #expect(place.coordinate == vienna)
        #expect(await source.fixCalls == 2)
    }

    @Test func concurrentCallersOfAFailedFixAllReceiveTheError() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.failure(.denied))
        await source.enqueueFix(.success(oslo))
        await source.holdNextFix()
        let service = makeService(source)

        async let first = result(of: service)
        async let second = result(of: service)
        await source.waitUntilFixBegan()
        await letCallersJoinTheHeldFix()
        await source.releaseFix()

        let results = await [first, second]
        #expect(results == [.failure(.denied), .failure(.denied)])
        #expect(await source.fixCalls == 1)

        let later = try await service.current()
        #expect(later.coordinate == oslo)
        #expect(await source.fixCalls == 2)
    }

    @Test func missingPlaceNameYieldsNil() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.success(vienna))
        let service = makeService(source)

        #expect(try await service.current() == LocatedPlace(coordinate: vienna, name: nil))
    }

    @Test func geocodesOncePerFetchAndNeverForAReusedFix() async throws {
        let source = FakeLocationFixSource(authorization: .authorized)
        await source.enqueueFix(.success(vienna))
        await source.enqueueFix(.success(oslo))
        await source.setPlaceName("Oslo", for: oslo)
        let service = makeService(source)

        _ = try await service.current()
        clock.advance(by: 30)
        _ = try await service.current()
        clock.advance(by: 30)
        let place = try await service.current()

        #expect(place == LocatedPlace(coordinate: oslo, name: "Oslo"))
        #expect(await source.geocodeCalls == [vienna, oslo])
    }

    private func result(of service: LocationService) async -> Result<LocatedPlace, LocationError> {
        do throws(LocationError) {
            return .success(try await service.current())
        } catch {
            return .failure(error)
        }
    }
}
