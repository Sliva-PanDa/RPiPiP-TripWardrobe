import Foundation

/// Адреса используемых веб-служб.
///
/// Каталог гардероба отдаётся статическим mock-сервером на GitHub Pages
/// (каталог `docs/api` этого же репозитория). Прогноз погоды берётся
/// из открытого сервиса Open-Meteo, не требующего ключа доступа.
enum API {

    /// Базовый адрес mock-сервера каталога.
    static let catalogBase = URL(string: "https://sliva-panda.github.io/RPiPiP-TripWardrobe/api")!

    /// GET /catalog.json — каталог сезонов, образов и вещей.
    static var catalog: URL {
        catalogBase.appendingPathComponent("catalog.json")
    }

    /// GET /v1/search — поиск координат города по названию.
    static func geocoding(city: String) -> URL {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: city),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "ru"),
            URLQueryItem(name: "format", value: "json")
        ]
        return components.url!
    }

    /// GET /v1/forecast — суточный прогноз на ближайшую неделю.
    static func forecast(latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily",
                         value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components.url!
    }
}

// MARK: - Структуры ответов Open-Meteo

/// Ответ службы геокодирования.
struct GeocodingResponse: Decodable {
    struct Place: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
    }
    let results: [Place]?
}

/// Ответ службы прогноза погоды.
/// Имена ключей в JSON не совпадают с именами свойств, сопоставление
/// выполняется перечислением `CodingKeys`.
struct ForecastResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let temperatureMax: [Double]
        let temperatureMin: [Double]
        let precipitationProbability: [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
            case precipitationProbability = "precipitation_probability_max"
        }
    }

    let daily: Daily

    /// Свёртка недельного прогноза в одну сводку для карточки поездки.
    func snapshot(city: String) -> WeatherSnapshot? {
        guard let minimum = daily.temperatureMin.min(),
              let maximum = daily.temperatureMax.max() else { return nil }
        let probabilities = daily.precipitationProbability.compactMap { $0 }
        return WeatherSnapshot(city: city,
                               minTemperature: minimum,
                               maxTemperature: maximum,
                               precipitationProbability: probabilities.max() ?? 0)
    }
}
