import Testing
@testable import WeatherFeature

@Suite struct WeatherCodeTests {
    static let conditionCases: [(Int, WeatherCondition)] = [
        (0, .clear),
        (1, .mostlyClear),
        (2, .partlyCloudy),
        (3, .overcast),
        (45, .fog), (48, .fog),
        (51, .drizzle), (53, .drizzle), (55, .drizzle),
        (56, .freezingDrizzle), (57, .freezingDrizzle),
        (61, .rain), (63, .rain), (65, .rain),
        (66, .freezingRain), (67, .freezingRain),
        (71, .snow), (73, .snow), (75, .snow),
        (77, .snowGrains),
        (80, .rainShowers), (81, .rainShowers), (82, .rainShowers),
        (85, .snowShowers), (86, .snowShowers),
        (95, .thunderstorm),
        (96, .thunderstormWithHail), (99, .thunderstormWithHail),
        (4, .unknown), (-1, .unknown),
    ]

    @Test(arguments: conditionCases)
    func conditionMatchesWMOTable(wmo: Int, expected: WeatherCondition) {
        #expect(WeatherCode(wmo: wmo).condition == expected)
    }

    @Test(arguments: [
        (95, PrecipitationKind.thunderstorm),
        (73, .snow),
        (61, .rain),
        (80, .rain),
    ] as [(Int, PrecipitationKind)])
    func precipitationKindForWetCodes(wmo: Int, expected: PrecipitationKind) {
        #expect(WeatherCode(wmo: wmo).precipitationKind == expected)
    }

    @Test(arguments: [3, 45])
    func precipitationKindIsNilForDryCodes(wmo: Int) {
        #expect(WeatherCode(wmo: wmo).precipitationKind == nil)
    }

    @Test(arguments: [0, 1, 2])
    func dayAndNightSymbolsDiffer(wmo: Int) {
        let code = WeatherCode(wmo: wmo)
        #expect(code.symbolName(isDay: true) != code.symbolName(isDay: false))
    }

    @Test(arguments: [3, 61, 95])
    func dayAndNightSymbolsMatch(wmo: Int) {
        let code = WeatherCode(wmo: wmo)
        #expect(code.symbolName(isDay: true) == code.symbolName(isDay: false))
    }
}
