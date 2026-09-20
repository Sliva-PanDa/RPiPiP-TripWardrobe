import Combine
import Foundation
import Observation

/// Модель представления карточки поездки (чемодана).
///
/// Отвечает за расчёт суммарного веса багажа, степень загрузки чемодана
/// относительно лимита авиакомпании и за автоматическое формирование
/// базового списка вещей по типу поездки и прогнозу погоды.
@Observable
final class TripDetailViewModel {

    /// Состояние загрузки прогноза погоды.
    enum WeatherState: Equatable {
        case idle
        case loading
        case loaded(WeatherSnapshot)
        case failed(String)

        var snapshot: WeatherSnapshot? {
            if case .loaded(let value) = self { return value }
            return nil
        }
    }

    private let repository: any WardrobeProviding & TripStoring
    private let weatherService: any WeatherProviding
    private let packingService: any PackingSuggesting

    /// Рабочая копия поездки: правки сохраняются в хранилище через `persist()`.
    private(set) var trip: Trip
    private(set) var weatherState: WeatherState = .idle
    private(set) var suggestions: [PackingSuggestion] = []

    var isAutoPackPresented = false
    var isExportPresented = false
    var isChecklistPreviewPresented = false

    /// Подписки Combine. Если коллекцию не сохранить в модели представления,
    /// подписка будет освобождена сразу после выхода из метода, и сетевой
    /// запрос отменится, не успев доставить результат.
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init(trip: Trip,
         repository: any WardrobeProviding & TripStoring,
         weatherService: any WeatherProviding,
         packingService: any PackingSuggesting) {
        self.trip = trip
        self.repository = repository
        self.weatherService = weatherService
        self.packingService = packingService
    }

    // MARK: - Расчёт веса багажа

    /// Суммарный вес уложенных вещей.
    var totalWeightGrams: Int { trip.totalWeightGrams }
    var totalWeightTitle: String { WeightFormatter.string(grams: totalWeightGrams) }

    var limitTitle: String { WeightFormatter.string(grams: trip.limitGrams) }

    /// Доля заполнения чемодана, ограниченная единицей для отображения полосой прогресса.
    var progress: Double { min(trip.load, 1.0) }

    /// Полная доля заполнения, в том числе при перевесе.
    var load: Double { trip.load }

    var loadPercentTitle: String { "\(Int((trip.load * 100).rounded()))" + " %" }

    var isOverLimit: Bool { trip.isOverLimit }

    /// Подпись под полосой прогресса: остаток или величина перевеса.
    var remainingTitle: String {
        let remaining = trip.remainingGrams
        if remaining >= 0 {
            return "Свободно \(WeightFormatter.string(grams: remaining))"
        }
        return "Перевес \(WeightFormatter.string(grams: -remaining))"
    }

    /// Предупреждение появляется, когда чемодан заполнен более чем на 85 %.
    var isNearLimit: Bool { trip.load >= 0.85 && !isOverLimit }

    var packedCountTitle: String { "\(trip.packedCount) из \(trip.items.count)" }

    /// Разбивка веса по категориям вещей — для наглядной сводки в карточке.
    var weightByCategory: [(category: String, grams: Int)] {
        Dictionary(grouping: trip.items, by: { $0.item.category })
            .map { (category: $0.key, grams: $0.value.reduce(0) { $0 + $1.totalWeightGrams }) }
            .sorted { $0.grams > $1.grams }
    }

    // MARK: - Погода

    /// Подписка на издателя прогноза погоды.
    ///
    /// Значение и ошибка приходят в главный поток, состояние экрана
    /// переключается в `.loaded` или `.failed`. Подписка сохраняется
    /// в коллекции `cancellables`, поэтому живёт столько же, сколько экран.
    @MainActor
    func loadWeather() {
        guard weatherState == .idle else { return }
        weatherState = .loading

        weatherService.forecastPublisher(city: trip.destination)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.weatherState = .failed(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] snapshot in
                    self?.weatherState = .loaded(snapshot)
                }
            )
            .store(in: &cancellables)
    }

    @MainActor
    func reloadWeather() {
        weatherState = .idle
        loadWeather()
    }

    // MARK: - Автоматическая сборка

    /// Формирует базовый список вещей по типу поездки и прогнозу погоды.
    func buildSuggestions() {
        suggestions = packingService.suggestions(for: trip,
                                                 weather: weatherState.snapshot,
                                                 wardrobe: repository.allPlacements)
        isAutoPackPresented = true
    }

    var suggestionsWeightTitle: String {
        WeightFormatter.string(grams: suggestions.reduce(0) { $0 + $1.totalWeightGrams })
    }

    /// Добавляет одну рекомендацию в чемодан.
    func apply(_ suggestion: PackingSuggestion) {
        guard !trip.items.contains(where: { $0.item.id == suggestion.item.id }) else { return }
        trip.items.append(PackedItem(item: suggestion.item,
                                     quantity: suggestion.quantity,
                                     isPacked: false,
                                     source: .automatic))
        repository.setStatus(.inTrip, forItem: suggestion.item.id)
        suggestions.removeAll { $0.id == suggestion.id }
        persist()
    }

    /// Добавляет весь предложенный список.
    func applyAllSuggestions() {
        for suggestion in suggestions {
            guard !trip.items.contains(where: { $0.item.id == suggestion.item.id }) else { continue }
            trip.items.append(PackedItem(item: suggestion.item,
                                         quantity: suggestion.quantity,
                                         isPacked: false,
                                         source: .automatic))
            repository.setStatus(.inTrip, forItem: suggestion.item.id)
        }
        suggestions.removeAll()
        isAutoPackPresented = false
        persist()
    }

    // MARK: - Правка содержимого чемодана

    func togglePacked(_ packed: PackedItem) {
        guard let index = trip.items.firstIndex(where: { $0.id == packed.id }) else { return }
        trip.items[index].isPacked.toggle()
        persist()
    }

    func changeQuantity(of packed: PackedItem, to quantity: Int) {
        guard let index = trip.items.firstIndex(where: { $0.id == packed.id }) else { return }
        trip.items[index].quantity = max(1, quantity)
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets {
            repository.setStatus(.inCloset, forItem: trip.items[index].item.id)
        }
        trip.items.remove(atOffsets: offsets)
        persist()
    }

    func setLimit(_ grams: Int) {
        trip.limitGrams = grams
        persist()
    }

    // MARK: - Экспорт чек-листа

    /// Чек-лист собранного чемодана для выгрузки в файл.
    var checklist: PackingChecklist { PackingChecklist(trip: trip) }

    var checklistDocument: ChecklistDocument { ChecklistDocument(checklist: checklist) }

    var checklistFileName: String { checklist.fileName }

    var canExport: Bool { !trip.items.isEmpty }

    /// Размер получающегося файла — выводится в интерфейсе.
    var checklistSizeTitle: String {
        let bytes = (try? checklist.encoded().count) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    func presentExport() {
        isExportPresented = true
    }

    func presentChecklistPreview() {
        isChecklistPreviewPresented = true
    }

    // MARK: - Сохранение

    private func persist() {
        repository.save(trip)
    }
}
