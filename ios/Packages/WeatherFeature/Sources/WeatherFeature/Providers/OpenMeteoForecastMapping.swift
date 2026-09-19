import Foundation

enum OpenMeteoForecastMapping {
    static func forecast(from data: Data, fetchedAt: Date) throws(WeatherError) -> Forecast {
        let response: ForecastResponse
        do {
            response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        } catch {
            throw .decoding
        }
        return try response.toForecast(fetchedAt: fetchedAt)
    }
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double
        let apparentTemperature: Double
        let weatherCode: Int
        let isDay: Int
        let windSpeed10m: Double
        let windGusts10m: Double

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case windSpeed10m = "wind_speed_10m"
            case windGusts10m = "wind_gusts_10m"
        }
    }

    struct Hourly: Decodable {
        let time: [Int]
        let temperature2m: [Double]
        let weatherCode: [Int]
        let precipitationProbability: [Int?]
        let windGusts10m: [Double?]
        let isDay: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case precipitationProbability = "precipitation_probability"
            case windGusts10m = "wind_gusts_10m"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [Int]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let precipitationProbabilityMax: [Int?]
        let sunrise: [Int]
        let sunset: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case sunrise
            case sunset
        }
    }

    let utcOffsetSeconds: Int
    let timezone: String
    let current: Current
    let hourly: Hourly
    let daily: Daily

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case timezone
        case current
        case hourly
        case daily
    }

    func toForecast(fetchedAt: Date) throws(WeatherError) -> Forecast {
        guard let zone = TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: utcOffsetSeconds) else {
            throw .decoding
        }

        let hourCount = hourly.time.count
        guard hourly.temperature2m.count == hourCount,
              hourly.weatherCode.count == hourCount,
              hourly.precipitationProbability.count == hourCount,
              hourly.windGusts10m.count == hourCount,
              hourly.isDay.count == hourCount
        else { throw .decoding }

        let dayCount = daily.time.count
        guard daily.weatherCode.count == dayCount,
              daily.temperature2mMax.count == dayCount,
              daily.temperature2mMin.count == dayCount,
              daily.precipitationProbabilityMax.count == dayCount,
              daily.sunrise.count == dayCount,
              daily.sunset.count == dayCount
        else { throw .decoding }

        let hours = (0..<hourCount).map { index in
            HourForecast(
                time: Date(timeIntervalSince1970: Double(hourly.time[index])),
                temperatureCelsius: hourly.temperature2m[index],
                code: WeatherCode(wmo: hourly.weatherCode[index]),
                isDay: hourly.isDay[index] == 1,
                precipitationProbability: hourly.precipitationProbability[index] ?? 0,
                windGustsKmh: hourly.windGusts10m[index] ?? 0
            )
        }

        let days = (0..<dayCount).map { index in
            DayForecast(
                date: Date(timeIntervalSince1970: Double(daily.time[index])),
                code: WeatherCode(wmo: daily.weatherCode[index]),
                highCelsius: daily.temperature2mMax[index],
                lowCelsius: daily.temperature2mMin[index],
                precipitationProbability: daily.precipitationProbabilityMax[index] ?? 0,
                sunrise: Date(timeIntervalSince1970: Double(daily.sunrise[index])),
                sunset: Date(timeIntervalSince1970: Double(daily.sunset[index]))
            )
        }

        return Forecast(
            timeZone: zone,
            current: CurrentConditions(
                temperatureCelsius: current.temperature2m,
                apparentTemperatureCelsius: current.apparentTemperature,
                code: WeatherCode(wmo: current.weatherCode),
                isDay: current.isDay == 1,
                windSpeedKmh: current.windSpeed10m,
                windGustsKmh: current.windGusts10m
            ),
            hourly: hours,
            daily: days,
            fetchedAt: fetchedAt
        )
    }
}
