import Foundation
import Observation

/// Источник данных интерфейса.
/// На этапе лабораторной работы № 1 демонстрационные данные хранятся в памяти;
/// в последующих работах этот же интерфейс будет обслуживаться базой данных SwiftData.
@Observable
final class WardrobeStore {
    var seasons: [SeasonStyle]

    init(seasons: [SeasonStyle] = SampleWardrobe.seasons) {
        self.seasons = seasons
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
}
