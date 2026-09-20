import Foundation
import Observation

/// Модель представления главного экрана гардероба.
///
/// Хранит состояние экрана (строка поиска, выбранные статусы, раскрытые образы)
/// и предоставляет представлению уже готовые к выводу данные. Доступ к гардеробу
/// идёт только через протокол `WardrobeProviding`.
@Observable
final class WardrobeListViewModel {

    private let repository: any WardrobeProviding

    var searchText: String = ""
    var statusFilter: Set<ItemStatus> = []
    var expandedLooks: Set<Look.ID> = []

    init(repository: any WardrobeProviding) {
        self.repository = repository
    }

    // MARK: - Производные данные для представления

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Иерархия с учётом выбранного фильтра по статусу.
    var seasons: [SeasonStyle] {
        repository.filteredSeasons(statuses: statusFilter)
    }

    /// Результаты текстового поиска с учётом фильтра.
    var searchResults: [ItemPlacement] {
        repository.search(searchText, statuses: statusFilter)
    }

    var seasonCount: Int { repository.seasons.count }
    var lookCount: Int { repository.seasons.reduce(0) { $0 + $1.looks.count } }
    var itemCount: Int { repository.allPlacements.count }

    var totalWeightTitle: String {
        WeightFormatter.string(grams: repository.allPlacements.reduce(0) { $0 + $1.item.weightGrams })
    }

    func count(of status: ItemStatus) -> Int {
        repository.count(of: status)
    }

    // MARK: - Действия пользователя

    func toggle(_ status: ItemStatus) {
        if statusFilter.contains(status) {
            statusFilter.remove(status)
        } else {
            statusFilter.insert(status)
        }
    }

    func resetFilter() {
        statusFilter.removeAll()
    }

    func isExpanded(_ id: Look.ID) -> Bool {
        expandedLooks.contains(id)
    }

    func setExpanded(_ isExpanded: Bool, for id: Look.ID) {
        if isExpanded {
            expandedLooks.insert(id)
        } else {
            expandedLooks.remove(id)
        }
    }

    // MARK: - Выборки для экранов деталей

    func season(id: SeasonStyle.ID) -> SeasonStyle? { repository.season(id: id) }
    func look(id: Look.ID) -> (season: SeasonStyle, look: Look)? { repository.look(id: id) }
    func placement(ofItem id: WardrobeItem.ID) -> ItemPlacement? { repository.placement(ofItem: id) }
}
