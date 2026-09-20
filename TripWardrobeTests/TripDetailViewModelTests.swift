import XCTest
@testable import TripWardrobe

/// Тесты модели представления карточки поездки: расчёт веса багажа,
/// загрузка прогноза и автоматическая сборка.
final class TripDetailViewModelTests: XCTestCase {

    private var store: WardrobeStore!

    override func setUp() {
        super.setUp()
        store = WardrobeStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    private func makeViewModel(trip: Trip) -> TripDetailViewModel {
        TripDetailViewModel(trip: trip,
                            repository: store,
                            weatherService: StubWeatherService(latency: .zero),
                            packingService: RuleBasedPackingService())
    }

    private func sampleTrip(limit: Int = BaggageLimit.cabin.grams,
                            items: [PackedItem] = []) -> Trip {
        let start = Date()
        return Trip(title: "Проверка",
                    destination: "Вильнюс",
                    kind: .business,
                    startDate: start,
                    endDate: Calendar.current.date(byAdding: .day, value: 4, to: start)!,
                    limitGrams: limit,
                    items: items)
    }

    // MARK: - Расчёт веса

    /// Суммарный вес равен сумме весов вещей с учётом количества.
    func testTotalWeightAccountsForQuantity() {
        let shirt = WardrobeItem(name: "Рубашка", category: "Верх", icon: "tshirt", weightGrams: 250)
        let shoes = WardrobeItem(name: "Туфли", category: "Обувь", icon: "figure.walk", weightGrams: 1_100)
        let viewModel = makeViewModel(trip: sampleTrip(items: [
            PackedItem(item: shirt, quantity: 3),
            PackedItem(item: shoes, quantity: 1)
        ]))

        XCTAssertEqual(viewModel.totalWeightGrams, 250 * 3 + 1_100)
        XCTAssertEqual(viewModel.totalWeightTitle, "1,85 кг")
    }

    /// Загрузка чемодана считается относительно лимита.
    func testLoadAndRemainingAgainstLimit() {
        let item = WardrobeItem(name: "Груз", category: "Верх", icon: "tshirt", weightGrams: 5_000)
        let viewModel = makeViewModel(trip: sampleTrip(limit: 10_000,
                                                       items: [PackedItem(item: item)]))

        XCTAssertEqual(viewModel.load, 0.5, accuracy: 0.0001)
        XCTAssertEqual(viewModel.loadPercentTitle, "50 %")
        XCTAssertFalse(viewModel.isOverLimit)
        XCTAssertEqual(viewModel.remainingTitle, "Свободно 5,00 кг")
    }

    /// Перевес отражается флагом и подписью.
    func testOverLimitIsDetected() {
        let item = WardrobeItem(name: "Груз", category: "Верх", icon: "tshirt", weightGrams: 12_500)
        let viewModel = makeViewModel(trip: sampleTrip(limit: 10_000,
                                                       items: [PackedItem(item: item)]))

        XCTAssertTrue(viewModel.isOverLimit)
        XCTAssertEqual(viewModel.remainingTitle, "Перевес 2,50 кг")
        XCTAssertEqual(viewModel.progress, 1.0, accuracy: 0.0001)
    }

    /// Смена лимита пересчитывает загрузку и сохраняется в хранилище.
    func testChangingLimitRecalculatesLoad() {
        let item = WardrobeItem(name: "Груз", category: "Верх", icon: "tshirt", weightGrams: 11_500)
        let viewModel = makeViewModel(trip: sampleTrip(limit: BaggageLimit.cabin.grams,
                                                       items: [PackedItem(item: item)]))
        XCTAssertTrue(viewModel.isOverLimit)

        viewModel.setLimit(BaggageLimit.checked.grams)

        XCTAssertFalse(viewModel.isOverLimit)
        XCTAssertEqual(store.trip(id: viewModel.trip.id)?.limitGrams, BaggageLimit.checked.grams)
    }

    /// Предупреждение о близости к лимиту включается после 85 % загрузки.
    func testNearLimitWarning() {
        let item = WardrobeItem(name: "Груз", category: "Верх", icon: "tshirt", weightGrams: 9_000)
        let viewModel = makeViewModel(trip: sampleTrip(limit: 10_000,
                                                       items: [PackedItem(item: item)]))
        XCTAssertTrue(viewModel.isNearLimit)
        XCTAssertFalse(viewModel.isOverLimit)
    }

    /// Разбивка по категориям суммирует вес и сортируется по убыванию.
    func testWeightBreakdownByCategory() {
        let top = WardrobeItem(name: "Верх", category: "Верх", icon: "tshirt", weightGrams: 300)
        let shoes = WardrobeItem(name: "Обувь", category: "Обувь", icon: "figure.walk", weightGrams: 1_000)
        let viewModel = makeViewModel(trip: sampleTrip(items: [
            PackedItem(item: top, quantity: 2),
            PackedItem(item: shoes, quantity: 1)
        ]))

        let breakdown = viewModel.weightByCategory
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown.first?.category, "Обувь")
        XCTAssertEqual(breakdown.first?.grams, 1_000)
        XCTAssertEqual(breakdown.last?.grams, 600)
    }

    // MARK: - Отметка «уложено»

    func testTogglePackedIsPersisted() throws {
        let item = WardrobeItem(name: "Свитер", category: "Верх", icon: "tshirt", weightGrams: 600)
        let viewModel = makeViewModel(trip: sampleTrip(items: [PackedItem(item: item)]))
        let packed = try XCTUnwrap(viewModel.trip.items.first)

        XCTAssertEqual(viewModel.packedCountTitle, "0 из 1")
        viewModel.togglePacked(packed)

        XCTAssertEqual(viewModel.packedCountTitle, "1 из 1")
        XCTAssertEqual(store.trip(id: viewModel.trip.id)?.items.first?.isPacked, true)
    }

    // MARK: - Погода

    /// Прогноз загружается через сервис и попадает в состояние модели.
    @MainActor
    func testWeatherIsLoadedFromService() async {
        let viewModel = makeViewModel(trip: sampleTrip())
        XCTAssertEqual(viewModel.weatherState, .idle)

        await viewModel.loadWeather()

        guard case .loaded(let snapshot) = viewModel.weatherState else {
            return XCTFail("Прогноз погоды не загружен")
        }
        XCTAssertEqual(snapshot.city, "Вильнюс")
        XCTAssertTrue(snapshot.isCold)
        XCTAssertTrue(snapshot.isRainy)
    }

    // MARK: - Автоматическая сборка

    /// Автосборка наполняет чемодан и переводит вещи в статус «В поездке».
    @MainActor
    func testAutomaticPackingFillsSuitcase() async {
        let viewModel = makeViewModel(trip: sampleTrip())
        await viewModel.loadWeather()

        viewModel.buildSuggestions()
        XCTAssertFalse(viewModel.suggestions.isEmpty)
        XCTAssertTrue(viewModel.isAutoPackPresented)

        let expected = viewModel.suggestions.count
        viewModel.applyAllSuggestions()

        XCTAssertEqual(viewModel.trip.items.count, expected)
        XCTAssertTrue(viewModel.trip.items.allSatisfy { $0.source == .automatic })
        XCTAssertGreaterThan(viewModel.totalWeightGrams, 0)
        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertFalse(viewModel.isAutoPackPresented)

        // Вещи, попавшие в чемодан, отмечены в гардеробе как «В поездке».
        for packed in viewModel.trip.items {
            XCTAssertEqual(store.placement(ofItem: packed.item.id)?.item.status, .inTrip)
        }
    }

    /// Повторная автосборка не дублирует уже уложенные вещи.
    @MainActor
    func testRepeatedPackingDoesNotDuplicate() async {
        let viewModel = makeViewModel(trip: sampleTrip())
        viewModel.buildSuggestions()
        viewModel.applyAllSuggestions()
        let firstPass = viewModel.trip.items.count

        viewModel.buildSuggestions()
        viewModel.applyAllSuggestions()

        let ids = viewModel.trip.items.map(\.item.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(viewModel.trip.items.count, firstPass)
    }
}
