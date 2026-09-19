import Testing
@testable import DaybookPlatform

@Suite struct CoordinateTests {
    @Test func roundsToTwoDecimals() {
        let rounded = Coordinate(latitude: 48.20849, longitude: 16.37208).rounded()
        #expect(rounded == Coordinate(latitude: 48.21, longitude: 16.37))
    }

    @Test func roundsNegativeValuesAwayFromTruncation() {
        let rounded = Coordinate(latitude: -33.86785, longitude: -151.20732).rounded()
        #expect(rounded == Coordinate(latitude: -33.87, longitude: -151.21))
    }

    @Test func nearbyPointsShareOneRoundedValue() {
        let home = Coordinate(latitude: 48.2082, longitude: 16.3738).rounded()
        let street = Coordinate(latitude: 48.2091, longitude: 16.3744).rounded()
        #expect(home == street)
    }

    @Test func roundingIsIdempotent() {
        let once = Coordinate(latitude: 59.91273, longitude: 10.74609).rounded()
        #expect(once.rounded() == once)
    }
}
