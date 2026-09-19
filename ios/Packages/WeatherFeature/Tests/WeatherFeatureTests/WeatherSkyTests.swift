import DaybookPlatform
import Testing
@testable import WeatherFeature

@Suite struct WeatherSkyTests {
    @Test func nightWinsOverEveryCondition() {
        for condition in WeatherCondition.allCases {
            #expect(sky(for: condition, isDay: false) == .night)
        }
    }

    @Test(arguments: [WeatherCondition.clear, .mostlyClear, .partlyCloudy])
    func clearConditionsUseTheClearDaySky(condition: WeatherCondition) {
        #expect(sky(for: condition, isDay: true) == .clearDay)
    }

    @Test(arguments: [WeatherCondition.overcast, .fog, .unknown])
    func cloudyConditionsUseTheCloudyDaySky(condition: WeatherCondition) {
        #expect(sky(for: condition, isDay: true) == .cloudyDay)
    }

    @Test func everyPrecipitatingConditionUsesTheRainDaySky() {
        let precipitating = WeatherCondition.allCases.filter { condition in
            wmoCodes(for: condition).contains { WeatherCode(wmo: $0).precipitationKind != nil }
        }
        #expect(!precipitating.isEmpty)
        for condition in precipitating {
            #expect(sky(for: condition, isDay: true) == .rainDay)
        }
    }

    @Test func mapsAWholeForecastByItsCurrentConditions() {
        #expect(sky(for: Forecast.fixtureVienna) == .clearDay)
        #expect(sky(for: Forecast.fixtureToronto) == .night)
    }

    @Test func screenStatesCompareByValue() {
        #expect(WeatherScreenState.loading == .loading)
        #expect(WeatherScreenState.failed(.offline) != .failed(.server))
        #expect(
            WeatherScreenState.loaded(.fixtureVienna, placeName: "Vienna", isOffline: false)
                != .loaded(.fixtureVienna, placeName: "Vienna", isOffline: true)
        )
    }

    private func wmoCodes(for condition: WeatherCondition) -> [Int] {
        (0...99).filter { WeatherCode(wmo: $0).condition == condition }
    }
}
