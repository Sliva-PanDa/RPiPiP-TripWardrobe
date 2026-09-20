import Foundation

/// Прогноз погоды в точке назначения на период поездки.
struct WeatherSnapshot: Hashable {
    var city: String
    var minTemperature: Double
    var maxTemperature: Double
    /// Вероятность осадков, проценты.
    var precipitationProbability: Int

    /// Холодно — нужны утеплённые вещи.
    var isCold: Bool { minTemperature < 8 }
    /// Жарко — нужны лёгкие вещи и запас футболок.
    var isHot: Bool { maxTemperature > 24 }
    /// Высокая вероятность осадков — нужна защита от дождя.
    var isRainy: Bool { precipitationProbability >= 40 }

    var summary: String {
        let range = String(format: "%.0f…%.0f °C", minTemperature, maxTemperature)
        return "\(range), осадки \(precipitationProbability) %"
    }

    var icon: String {
        if isRainy { return "cloud.rain" }
        if isCold { return "snowflake" }
        if isHot { return "sun.max" }
        return "cloud.sun"
    }
}
