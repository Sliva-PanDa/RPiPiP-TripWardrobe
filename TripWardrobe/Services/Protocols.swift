import Combine
import Foundation

/// Чтение и изменение гардероба.
/// Протокол отделяет слой представления от способа хранения данных:
/// в лабораторной работе № 2 его реализует хранилище в памяти,
/// в лабораторной работе № 3 — база данных SwiftData.
protocol WardrobeProviding: AnyObject {
    var seasons: [SeasonStyle] { get }
    var allPlacements: [ItemPlacement] { get }

    func search(_ query: String, statuses: Set<ItemStatus>) -> [ItemPlacement]
    func filteredSeasons(statuses: Set<ItemStatus>) -> [SeasonStyle]
    func count(of status: ItemStatus) -> Int

    func season(id: SeasonStyle.ID) -> SeasonStyle?
    func look(id: Look.ID) -> (season: SeasonStyle, look: Look)?
    func placement(ofItem id: WardrobeItem.ID) -> ItemPlacement?

    func setStatus(_ status: ItemStatus, forItem id: WardrobeItem.ID)
}

/// Хранение поездок (чемоданов).
protocol TripStoring: AnyObject {
    var trips: [Trip] { get }

    func trip(id: Trip.ID) -> Trip?
    func save(_ trip: Trip)
    func delete(tripID: Trip.ID)
}

/// Источник прогноза погоды.
///
/// Начиная с лабораторной работы № 4 интерфейс реактивный: сервис возвращает
/// издателя Combine, на которого подписывается модель представления.
/// Локальная заглушка и сетевая реализация поверх REST API взаимозаменяемы.
protocol WeatherProviding: AnyObject {
    func forecastPublisher(city: String) -> AnyPublisher<WeatherSnapshot, NetworkError>
}

/// Алгоритм автоматического формирования базового списка вещей.
protocol PackingSuggesting: AnyObject {
    func suggestions(for trip: Trip,
                     weather: WeatherSnapshot?,
                     wardrobe: [ItemPlacement]) -> [PackingSuggestion]
}

/// Рекомендация алгоритма: какую вещь и в каком количестве взять и почему.
struct PackingSuggestion: Identifiable, Hashable {
    let id: UUID
    let item: WardrobeItem
    let quantity: Int
    /// Человекочитаемое обоснование — выводится в интерфейсе.
    let reason: String

    init(id: UUID = UUID(), item: WardrobeItem, quantity: Int, reason: String) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.reason = reason
    }

    var totalWeightGrams: Int { item.weightGrams * quantity }
}
