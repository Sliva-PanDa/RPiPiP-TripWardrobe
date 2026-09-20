import Foundation

/// Локальный источник прогноза погоды для лабораторной работы № 2.
///
/// Модель представления работает с протоколом `WeatherProviding` и не знает,
/// откуда берутся данные. В лабораторной работе № 4 эта реализация будет
/// заменена на сетевую (REST API + Combine) без правок слоя представления.
final class StubWeatherService: WeatherProviding {

    /// Заранее известные города с характерной погодой.
    private let table: [String: WeatherSnapshot] = [
        "батуми":   WeatherSnapshot(city: "Батуми", minTemperature: 21, maxTemperature: 29,
                                    precipitationProbability: 20),
        "вильнюс":  WeatherSnapshot(city: "Вильнюс", minTemperature: 3, maxTemperature: 9,
                                    precipitationProbability: 55),
        "буковель": WeatherSnapshot(city: "Буковель", minTemperature: -9, maxTemperature: -1,
                                    precipitationProbability: 65),
        "гомель":   WeatherSnapshot(city: "Гомель", minTemperature: 6, maxTemperature: 14,
                                    precipitationProbability: 35)
    ]

    /// Искусственная задержка, имитирующая обращение к сети.
    private let latency: Duration

    init(latency: Duration = .milliseconds(400)) {
        self.latency = latency
    }

    func forecast(city: String) async throws -> WeatherSnapshot {
        try await Task.sleep(for: latency)

        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let snapshot = table[key] {
            return snapshot
        }
        // Для неизвестного города возвращается усреднённый прогноз,
        // детерминированно выведенный из названия.
        let seed = key.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 18 }
        return WeatherSnapshot(city: city,
                               minTemperature: Double(seed) - 2,
                               maxTemperature: Double(seed) + 7,
                               precipitationProbability: (seed * 5) % 80)
    }
}
