import Combine
import Foundation
import Observation

/// Модель представления главного экрана гардероба.
///
/// Хранит состояние экрана (строка поиска, выбранные статусы, раскрытые образы)
/// и предоставляет представлению уже готовые к выводу данные. Доступ к гардеробу
/// идёт только через протокол `WardrobeProviding`.
///
/// Ввод в строке поиска пропускается через конвейер Combine: оператор
/// `debounce` откладывает обработку на 300 мс, а `removeDuplicates`
/// отбрасывает повторяющиеся значения. Поэтому при быстром наборе
/// выборка выполняется один раз, а не на каждое нажатие клавиши.
@Observable
final class WardrobeListViewModel {

    @ObservationIgnored private let repository: any WardrobeProviding

    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            querySubject.send(searchText)
        }
    }

    var statusFilter: Set<ItemStatus> = []
    var expandedLooks: Set<Look.ID> = []

    /// Запрос, дошедший до выборки после задержки ввода.
    private(set) var debouncedQuery: String = ""
    /// Счётчик выполненных выборок — используется в тестах конвейера.
    private(set) var queryCount = 0

    @ObservationIgnored private let querySubject = CurrentValueSubject<String, Never>("")
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init(repository: any WardrobeProviding,
         debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300)) {
        self.repository = repository

        querySubject
            // Задержка ввода: выборка запускается, когда пользователь остановился.
            .debounce(for: debounce, scheduler: DispatchQueue.main)
            // Исключение дублирующих запросов с одинаковым текстом.
            .removeDuplicates()
            .sink { [weak self] query in
                self?.debouncedQuery = query
                self?.queryCount += 1
            }
            .store(in: &cancellables)
    }

    // MARK: - Производные данные для представления

    /// Экран показывает результаты поиска, а не иерархию.
    /// Признак считается по запросу, дошедшему до выборки, поэтому
    /// содержимое экрана не дёргается на каждое нажатие клавиши.
    var isSearching: Bool {
        !debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Пользователь ещё набирает запрос, выборка пока не пересчитана.
    var isTypingAhead: Bool { debouncedQuery != searchText }

    /// Иерархия с учётом выбранного фильтра по статусу.
    var seasons: [SeasonStyle] {
        repository.filteredSeasons(statuses: statusFilter)
    }

    /// Результаты текстового поиска с учётом фильтра.
    var searchResults: [ItemPlacement] {
        repository.search(debouncedQuery, statuses: statusFilter)
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
