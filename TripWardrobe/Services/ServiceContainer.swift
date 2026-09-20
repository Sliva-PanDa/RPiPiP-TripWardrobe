import Foundation
import Observation

/// Контейнер зависимостей приложения.
///
/// Собирается один раз в точке входа и передаётся вниз по иерархии экранов
/// через environment. Модели представления получают зависимости через
/// инициализатор и работают только с протоколами, поэтому любую реализацию
/// можно подменить — в том числе на тестовую.
@Observable
final class ServiceContainer {
    let repository: any WardrobeProviding & TripStoring
    let weather: any WeatherProviding
    let packing: any PackingSuggesting

    init(repository: any WardrobeProviding & TripStoring = WardrobeStore(),
         weather: any WeatherProviding = StubWeatherService(),
         packing: any PackingSuggesting = RuleBasedPackingService()) {
        self.repository = repository
        self.weather = weather
        self.packing = packing
    }
}
