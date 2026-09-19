import SwiftUI

struct RGB: Sendable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    static let white = RGB(red: 1, green: 1, blue: 1)
    static let black = RGB(red: 0, green: 0, blue: 0)

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

struct TranslucentRGB: Sendable, Hashable {
    var base: RGB
    var opacity: Double

    var color: Color {
        Color(.sRGB, red: base.red, green: base.green, blue: base.blue, opacity: opacity)
    }

    func composited(over background: RGB) -> RGB {
        RGB(
            red: base.red * opacity + background.red * (1 - opacity),
            green: base.green * opacity + background.green * (1 - opacity),
            blue: base.blue * opacity + background.blue * (1 - opacity)
        )
    }
}

func contrastRatio(_ lhs: RGB, _ rhs: RGB) -> Double {
    let first = lhs.relativeLuminance
    let second = rhs.relativeLuminance
    let lighter = max(first, second)
    let darker = min(first, second)
    return (lighter + 0.05) / (darker + 0.05)
}

public struct Theme: Sendable {
    public enum Sky: Sendable, CaseIterable {
        case clearDay, cloudyDay, rainDay, night
    }

    public struct Spacing: Sendable {
        public var small: CGFloat
        public var medium: CGFloat
        public var large: CGFloat

        public init(small: CGFloat, medium: CGFloat, large: CGFloat) {
            self.small = small
            self.medium = medium
            self.large = large
        }
    }

    public var spacing: Spacing

    public init(spacing: Spacing) {
        self.spacing = spacing
    }

    public static let standard = Theme(spacing: Spacing(small: 8, medium: 16, large: 24))

    func gradientStops(_ sky: Sky) -> GradientStops {
        switch sky {
        case .clearDay:
            GradientStops(
                top: RGB(red: 0x28 / 255, green: 0x67 / 255, blue: 0xBF / 255),
                bottom: RGB(red: 0x3B / 255, green: 0x77 / 255, blue: 0xC8 / 255)
            )
        case .cloudyDay:
            GradientStops(
                top: RGB(red: 0x4B / 255, green: 0x5A / 255, blue: 0x6B / 255),
                bottom: RGB(red: 0x69 / 255, green: 0x78 / 255, blue: 0x89 / 255)
            )
        case .rainDay:
            GradientStops(
                top: RGB(red: 0x3E / 255, green: 0x4C / 255, blue: 0x5C / 255),
                bottom: RGB(red: 0x67 / 255, green: 0x78 / 255, blue: 0x88 / 255)
            )
        case .night:
            GradientStops(
                top: RGB(red: 0x0A / 255, green: 0x0F / 255, blue: 0x2A / 255),
                bottom: RGB(red: 0x2B / 255, green: 0x3A / 255, blue: 0x67 / 255)
            )
        }
    }

    public func skyGradient(_ sky: Sky) -> [Color] {
        let stops = gradientStops(sky)
        return [stops.top.color, stops.bottom.color]
    }

    var cardFillColor: TranslucentRGB { TranslucentRGB(base: .black, opacity: 0.22) }

    public var cardFill: Color { cardFillColor.color }

    public var cardStroke: Color { TranslucentRGB(base: .white, opacity: 0.2).color }
}

struct GradientStops: Sendable, Hashable {
    var top: RGB
    var bottom: RGB
}

public extension EnvironmentValues {
    @Entry var theme: Theme = .standard
}
