enum WeatherError: Error, Sendable, Equatable { case offline, server, decoding, notFound }
