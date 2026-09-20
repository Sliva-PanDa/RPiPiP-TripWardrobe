import Combine
import Foundation

/// Получение прогноза погоды по REST API средствами фреймворка Combine.
///
/// Цепочка состоит из двух последовательных запросов: сначала по названию
/// города определяются координаты (геокодирование), затем по координатам
/// запрашивается суточный прогноз. Запросы связываются оператором `flatMap`,
/// сырые данные превращаются в модель операторами `tryMap` и `decode`,
/// а результат доставляется в главный поток оператором `receive(on:)`.
final class OpenMeteoWeatherService: WeatherProviding {

    private let session: URLSession
    private let decoder = JSONDecoder()
    /// Кэш координат: повторный вход в карточку поездки не вызывает геокодирование заново.
    private var coordinateCache: [String: GeocodingResponse.Place] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func forecastPublisher(city: String) -> AnyPublisher<WeatherSnapshot, NetworkError> {
        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let place: AnyPublisher<GeocodingResponse.Place, NetworkError>
        if let cached = coordinateCache[key] {
            place = Just(cached)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            place = geocode(city: city)
        }

        return place
            // Последовательное связывание двух сетевых запросов.
            .flatMap { [weak self] place -> AnyPublisher<WeatherSnapshot, NetworkError> in
                guard let self else {
                    return Fail(error: NetworkError.unreachable("сервис освобождён"))
                        .eraseToAnyPublisher()
                }
                self.coordinateCache[key] = place
                return self.forecast(for: place)
            }
            // Ответ доставляется в главный поток: подписчик обновляет интерфейс.
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Отдельные запросы

    private func geocode(city: String) -> AnyPublisher<GeocodingResponse.Place, NetworkError> {
        session.dataTaskPublisher(for: API.geocoding(city: city))
            // Сетевая работа выполняется вне главного потока.
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .tryMap { data, response in
                try HTTPValidator.validate(response)
                return data
            }
            .decode(type: GeocodingResponse.self, decoder: decoder)
            .tryMap { response in
                guard let first = response.results?.first else {
                    throw NetworkError.notFound("город «\(city)»")
                }
                return first
            }
            .mapError(NetworkError.wrap)
            .eraseToAnyPublisher()
    }

    private func forecast(for place: GeocodingResponse.Place)
        -> AnyPublisher<WeatherSnapshot, NetworkError> {
        session.dataTaskPublisher(
            for: API.forecast(latitude: place.latitude, longitude: place.longitude))
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .tryMap { data, response in
                try HTTPValidator.validate(response)
                return data
            }
            .decode(type: ForecastResponse.self, decoder: decoder)
            .tryMap { response in
                guard let snapshot = response.snapshot(city: place.name) else {
                    throw NetworkError.decoding("пустой прогноз")
                }
                return snapshot
            }
            .mapError(NetworkError.wrap)
            .eraseToAnyPublisher()
    }
}

/// Источник погоды с резервным вариантом.
///
/// Если сетевой сервис вернул ошибку (нет интернета, сервис недоступен,
/// код 4xx/5xx), оператор `catch` подставляет локальный прогноз, и карточка
/// поездки продолжает работать. Это же поведение используется в симуляторе
/// без доступа к сети.
final class FallbackWeatherService: WeatherProviding {

    private let primary: any WeatherProviding
    private let reserve: any WeatherProviding
    /// Признак того, что последний прогноз получен из резервного источника.
    private(set) var usedReserve = false

    init(primary: any WeatherProviding = OpenMeteoWeatherService(),
         reserve: any WeatherProviding = StubWeatherService(latency: .milliseconds(200))) {
        self.primary = primary
        self.reserve = reserve
    }

    func forecastPublisher(city: String) -> AnyPublisher<WeatherSnapshot, NetworkError> {
        primary.forecastPublisher(city: city)
            .handleEvents(receiveOutput: { [weak self] _ in self?.usedReserve = false })
            .catch { [weak self] _ -> AnyPublisher<WeatherSnapshot, NetworkError> in
                self?.usedReserve = true
                return self?.reserve.forecastPublisher(city: city)
                    ?? Fail(error: NetworkError.invalidResponse).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
