enum WeatherCondition: String, Sendable, Codable, CaseIterable {
    case clear, mostlyClear, partlyCloudy, overcast, fog, drizzle, freezingDrizzle,
         rain, freezingRain, snow, snowGrains, rainShowers, snowShowers, thunderstorm, thunderstormWithHail, unknown
}

enum PrecipitationKind: String, Sendable, Codable { case rain, snow, thunderstorm }

struct WeatherCode: Sendable, Codable, Hashable {
    let wmo: Int

    init(wmo: Int) {
        self.wmo = wmo
    }

    init(from decoder: any Decoder) throws {
        self.init(wmo: try decoder.singleValueContainer().decode(Int.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wmo)
    }

    var condition: WeatherCondition {
        switch wmo {
        case 0: .clear
        case 1: .mostlyClear
        case 2: .partlyCloudy
        case 3: .overcast
        case 45, 48: .fog
        case 51, 53, 55: .drizzle
        case 56, 57: .freezingDrizzle
        case 61, 63, 65: .rain
        case 66, 67: .freezingRain
        case 71, 73, 75: .snow
        case 77: .snowGrains
        case 80, 81, 82: .rainShowers
        case 85, 86: .snowShowers
        case 95: .thunderstorm
        case 96, 99: .thunderstormWithHail
        default: .unknown
        }
    }

    var precipitationKind: PrecipitationKind? {
        switch condition {
        case .thunderstorm, .thunderstormWithHail: .thunderstorm
        case .snow, .snowGrains, .snowShowers: .snow
        case .drizzle, .freezingDrizzle, .rain, .freezingRain, .rainShowers: .rain
        case .clear, .mostlyClear, .partlyCloudy, .overcast, .fog, .unknown: nil
        }
    }

    func symbolName(isDay: Bool) -> String {
        switch condition {
        case .clear: isDay ? "sun.max.fill" : "moon.stars.fill"
        case .mostlyClear, .partlyCloudy: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .drizzle, .freezingDrizzle: "cloud.drizzle.fill"
        case .rain, .freezingRain: "cloud.rain.fill"
        case .rainShowers: "cloud.heavyrain.fill"
        case .snow, .snowGrains, .snowShowers: "cloud.snow.fill"
        case .thunderstorm, .thunderstormWithHail: "cloud.bolt.rain.fill"
        case .unknown: "questionmark.circle"
        }
    }
}
