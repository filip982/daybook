import Testing
@testable import DaybookPlatform

@Suite struct ThemeTests {
    let theme = Theme.standard

    @Test func standardSpacingIsEightSixteenTwentyFour() {
        #expect(theme.spacing.small == 8)
        #expect(theme.spacing.medium == 16)
        #expect(theme.spacing.large == 24)
    }

    @Test func everySkyReturnsExactlyTwoColors() {
        for sky in Theme.Sky.allCases {
            #expect(theme.skyGradient(sky).count == 2)
        }
    }

    @Test func noTwoSkiesShareTheSameGradient() {
        let stops = Theme.Sky.allCases.map { theme.gradientStops($0) }
        #expect(Set(stops).count == Theme.Sky.allCases.count)
    }

    @Test func blackOnWhiteIsTwentyOne() {
        let ratio = contrastRatio(RGB(red: 0, green: 0, blue: 0), .white)
        #expect(abs(ratio - 21) < 0.01)
    }

    @Test func whiteOnWhiteIsOne() {
        #expect(abs(contrastRatio(.white, .white) - 1) < 0.0001)
    }

    @Test func contrastRatioIsSymmetric() {
        let navy = RGB(red: 0x0A / 255, green: 0x0F / 255, blue: 0x2A / 255)
        #expect(abs(contrastRatio(navy, .white) - contrastRatio(.white, navy)) < 0.0001)
    }

    @Test(arguments: Theme.Sky.allCases)
    func everyGradientStopIsReadableUnderWhiteText(sky: Theme.Sky) {
        let stops = theme.gradientStops(sky)
        #expect(contrastRatio(stops.top, .white) >= 4.5)
        #expect(contrastRatio(stops.bottom, .white) >= 4.5)
    }

    @Test(arguments: Theme.Sky.allCases)
    func whiteTextOnACardStaysReadableOverEverySky(sky: Theme.Sky) {
        let stops = theme.gradientStops(sky)
        for background in [stops.top, stops.bottom] {
            let card = theme.cardFillColor.composited(over: background)
            #expect(contrastRatio(card, .white) >= 4.5)
        }
    }

    @Test func theCardDarkensTheSkyRatherThanLighteningIt() {
        for sky in Theme.Sky.allCases {
            let stops = theme.gradientStops(sky)
            for background in [stops.top, stops.bottom] {
                let card = theme.cardFillColor.composited(over: background)
                #expect(card.relativeLuminance <= background.relativeLuminance)
            }
        }
    }
}
