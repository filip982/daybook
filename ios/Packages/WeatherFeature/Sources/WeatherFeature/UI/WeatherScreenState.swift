enum WeatherScreenState: Equatable {
    case locationNotAsked
    case locationDenied
    case loading
    case loaded(Forecast, placeName: String, isOffline: Bool)
    case failed(WeatherError)
}
