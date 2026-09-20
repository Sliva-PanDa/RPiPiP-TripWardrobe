import Foundation
import Observation

/// Реализация хранилища в оперативной памяти.
/// Скрыта за протоколами `WardrobeProviding` и `TripStoring`, поэтому
/// модели представления не знают, откуда приходят данные: в лабораторной
/// работе № 3 эту же роль возьмёт на себя база данных SwiftData.
@Observable
final class WardrobeStore: WardrobeProviding, TripStoring {
    var seasons: [SeasonStyle]
    private(set) var trips: [Trip]

    init(seasons: [SeasonStyle] = SampleWardrobe.seasons,
         trips: [Trip] = SampleWardrobe.trips) {
        self.seasons = seasons
        self.trips = trips
    }

    // MARK: - Сводные показатели

    var lookCount: Int { seasons.reduce(0) { $0 + $1.looks.count } }
    var itemCount: Int { seasons.reduce(0) { $0 + $1.itemCount } }
    var totalWeightGrams: Int { seasons.reduce(0) { $0 + $1.totalWeightGrams } }

    /// Количество вещей с указанным статусом.
    func count(of status: ItemStatus) -> Int {
        allPlacements.filter { $0.item.status == status }.count
    }

    // MARK: - Плоское представление иерархии

    /// Все вещи гардероба вместе с их местоположением.
    var allPlacements: [ItemPlacement] {
        seasons.flatMap { season in
            season.looks.flatMap { look in
                look.items.map { ItemPlacement(season: season, look: look, item: $0) }
            }
        }
    }

    // MARK: - Выборки по идентификаторам

    func season(id: SeasonStyle.ID) -> SeasonStyle? {
        seasons.first { $0.id == id }
    }

    func look(id: Look.ID) -> (season: SeasonStyle, look: Look)? {
        for season in seasons {
            if let look = season.looks.first(where: { $0.id == id }) {
                return (season, look)
            }
        }
        return nil
    }

    func placement(ofItem id: WardrobeItem.ID) -> ItemPlacement? {
        allPlacements.first { $0.item.id == id }
    }

    // MARK: - Поиск и фильтрация

    /// Текстовый поиск по вещам с фильтрацией по статусу.
    /// - Parameters:
    ///   - query: строка запроса; сравнение ведётся по названию, категории и заметке без учёта регистра.
    ///   - statuses: набор допустимых статусов; пустой набор означает «показывать все».
    /// - Returns: найденные вещи с указанием их местоположения, отсортированные по алфавиту.
    func search(_ query: String, statuses: Set<ItemStatus> = []) -> [ItemPlacement] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return allPlacements
            .filter { statuses.isEmpty || statuses.contains($0.item.status) }
            .filter { placement in
                guard !text.isEmpty else { return true }
                return placement.item.name.localizedCaseInsensitiveContains(text)
                    || placement.item.category.localizedCaseInsensitiveContains(text)
                    || placement.item.note.localizedCaseInsensitiveContains(text)
            }
            .sorted { $0.item.name.localizedCompare($1.item.name) == .orderedAscending }
    }

    /// Иерархия, отфильтрованная по статусу вещей.
    /// Образы и сезоны, в которых не осталось подходящих вещей, из выдачи исключаются.
    func filteredSeasons(statuses: Set<ItemStatus>) -> [SeasonStyle] {
        guard !statuses.isEmpty else { return seasons }
        return seasons.compactMap { season in
            let looks = season.looks.compactMap { look -> Look? in
                let items = look.items.filter { statuses.contains($0.status) }
                guard !items.isEmpty else { return nil }
                var copy = look
                copy.items = items
                return copy
            }
            guard !looks.isEmpty else { return nil }
            var copy = season
            copy.looks = looks
            return copy
        }
    }

    // MARK: - Изменение гардероба

    /// Перевод вещи в другой статус («В шкафу», «В поездке», «В стирке»).
    func setStatus(_ status: ItemStatus, forItem id: WardrobeItem.ID) {
        for seasonIndex in seasons.indices {
            for lookIndex in seasons[seasonIndex].looks.indices {
                guard let itemIndex = seasons[seasonIndex].looks[lookIndex]
                    .items.firstIndex(where: { $0.id == id }) else { continue }
                seasons[seasonIndex].looks[lookIndex].items[itemIndex].status = status
                return
            }
        }
    }

    // MARK: - Поездки

    func trip(id: Trip.ID) -> Trip? {
        trips.first { $0.id == id }
    }

    func save(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        } else {
            trips.append(trip)
        }
    }

    func delete(tripID: Trip.ID) {
        trips.removeAll { $0.id == tripID }
    }
}
