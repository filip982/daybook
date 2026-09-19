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
        let time: [String]
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
        let time: [String]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let precipitationProbabilityMax: [Int?]
        let sunrise: [String]
        let sunset: [String]

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

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

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

        var hours: [HourForecast] = []
        hours.reserveCapacity(hourCount)
        for index in 0..<hourCount {
            guard let time = calendar.dateFromMinuteStamp(hourly.time[index]) else { throw .decoding }
            hours.append(
                HourForecast(
                    time: time,
                    temperatureCelsius: hourly.temperature2m[index],
                    code: WeatherCode(wmo: hourly.weatherCode[index]),
                    isDay: hourly.isDay[index] == 1,
                    precipitationProbability: hourly.precipitationProbability[index] ?? 0,
                    windGustsKmh: hourly.windGusts10m[index] ?? 0
                )
            )
        }

        var days: [DayForecast] = []
        days.reserveCapacity(dayCount)
        for index in 0..<dayCount {
            guard let date = calendar.dateFromDayStamp(daily.time[index]),
                  let sunrise = calendar.dateFromMinuteStamp(daily.sunrise[index]),
                  let sunset = calendar.dateFromMinuteStamp(daily.sunset[index])
            else { throw .decoding }

            days.append(
                DayForecast(
                    date: date,
                    code: WeatherCode(wmo: daily.weatherCode[index]),
                    highCelsius: daily.temperature2mMax[index],
                    lowCelsius: daily.temperature2mMin[index],
                    precipitationProbability: daily.precipitationProbabilityMax[index] ?? 0,
                    sunrise: sunrise,
                    sunset: sunset
                )
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

private extension Calendar {
    func dateFromDayStamp(_ stamp: String) -> Date? {
        let parts = stamp.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        return date(from: DateComponents(year: year, month: month, day: day))
    }

    func dateFromMinuteStamp(_ stamp: String) -> Date? {
        let halves = stamp.split(separator: "T")
        guard halves.count == 2 else { return nil }

        let date = halves[0].split(separator: "-")
        let clock = halves[1].split(separator: ":")
        guard date.count == 3, clock.count == 2,
              let year = Int(date[0]), let month = Int(date[1]), let day = Int(date[2]),
              let hour = Int(clock[0]), let minute = Int(clock[1])
        else { return nil }

        return self.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )
    }
}
