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

    @Test func loadedAccessibility5() {
        assertSnapshot(
            of: screen(.loaded(.fixtureVienna, placeName: "Vienna", isOffline: false))
                .dynamicTypeSize(.accessibility5),
            as: strategy(height: 1600, contentSize: .accessibilityExtraExtraExtraLarge)
        )
    }

    @Test func loading() {
        assertSnapshot(of: screen(.loading), as: strategy())
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

    private func screen(_ state: WeatherScreenState) -> some View {
        WeatherView(state: state, now: Self.now, locale: Self.locale)
            .environment(\.theme, .standard)
            .environment(\.timeZone, TimeZone(identifier: "Europe/Vienna")!)
            .transaction { $0.animation = nil }
    }

    private func strategy<V: View>(
        height: CGFloat = 852,
        contentSize: UIContentSizeCategory = .large
    ) -> Snapshotting<V, UIImage> {
        .image(
            perceptualPrecision: 0.98,
            layout: .fixed(width: 393, height: height),
            traits: UITraitCollection { mutable in
                mutable.displayScale = 2
                mutable.userInterfaceStyle = .light
                mutable.preferredContentSizeCategory = contentSize
            }
        )
    }
}
