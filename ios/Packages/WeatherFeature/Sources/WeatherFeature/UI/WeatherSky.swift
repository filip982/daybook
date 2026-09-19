import DaybookPlatform

func sky(for condition: WeatherCondition, isDay: Bool) -> Theme.Sky {
    guard isDay else { return .night }

    switch condition {
    case .clear, .mostlyClear, .partlyCloudy: return .clearDay
    case .overcast, .fog, .unknown: return .cloudyDay
    case .drizzle, .freezingDrizzle, .rain, .freezingRain, .snow, .snowGrains,
         .rainShowers, .snowShowers, .thunderstorm, .thunderstormWithHail: return .rainDay
    }
}

func sky(for forecast: Forecast) -> Theme.Sky {
    sky(for: forecast.current.code.condition, isDay: forecast.current.isDay)
}
