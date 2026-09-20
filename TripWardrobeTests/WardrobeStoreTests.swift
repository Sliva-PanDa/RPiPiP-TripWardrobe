import XCTest
@testable import TripWardrobe

/// Модульные тесты источника данных: иерархия, поиск и фильтрация по статусу.
final class WardrobeStoreTests: XCTestCase {

    private var store: WardrobeStore!

    override func setUp() {
        super.setUp()
        store = WardrobeStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    /// Демонстрационный гардероб разворачивается в плоский список вещей целиком.
    func testAllPlacementsCountMatchesHierarchy() {
        let expected = store.seasons.reduce(0) { $0 + $1.itemCount }
        XCTAssertEqual(store.allPlacements.count, expected)
        XCTAssertEqual(store.itemCount, expected)
    }

    /// Поиск возвращает вещь вместе с точным путём «Сезон/Стиль → Образ».
    func testSearchReturnsExactPlacementPath() {
        let results = store.search("Плавки")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.path, "Лето · Casual → Пляжный день")
    }

    /// Поиск не учитывает регистр и работает по категории вещи.
    func testSearchIsCaseInsensitiveAndMatchesCategory() {
        XCTAssertFalse(store.search("пиджак").isEmpty)
        XCTAssertFalse(store.search("ПИДЖАК").isEmpty)

        let shoes = store.search("обувь")
        XCTAssertTrue(shoes.allSatisfy { $0.item.category == "Обувь" })
        XCTAssertGreaterThan(shoes.count, 1)
    }

    /// Пустой запрос без фильтра возвращает весь гардероб.
    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(store.search("").count, store.itemCount)
    }

    /// Фильтр по статусу сужает выдачу поиска.
    func testSearchRespectsStatusFilter() {
        let inTrip = store.search("", statuses: [.inTrip])
        XCTAssertFalse(inTrip.isEmpty)
        XCTAssertTrue(inTrip.allSatisfy { $0.item.status == .inTrip })
        XCTAssertEqual(inTrip.count, store.count(of: .inTrip))
    }

    /// Несколько статусов объединяются по «или».
    func testSearchWithSeveralStatuses() {
        let mixed = store.search("", statuses: [.inTrip, .inLaundry])
        XCTAssertEqual(mixed.count, store.count(of: .inTrip) + store.count(of: .inLaundry))
    }

    /// Фильтрация иерархии скрывает образы и сезоны без подходящих вещей.
    func testFilteredSeasonsDropsEmptyBranches() {
        let filtered = store.filteredSeasons(statuses: [.inLaundry])
        let items = filtered.flatMap { $0.looks.flatMap(\.items) }

        XCTAssertFalse(filtered.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.status == .inLaundry })
        XCTAssertTrue(filtered.allSatisfy { !$0.looks.isEmpty })
        XCTAssertTrue(filtered.flatMap(\.looks).allSatisfy { !$0.items.isEmpty })
    }

    /// Пустой набор статусов означает «без фильтра».
    func testFilteredSeasonsWithoutFilterReturnsWholeWardrobe() {
        XCTAssertEqual(store.filteredSeasons(statuses: []).count, store.seasons.count)
    }

    /// Выборки по идентификаторам находят сезон, образ и вещь.
    func testLookupByIdentifiers() throws {
        let season = try XCTUnwrap(store.seasons.first)
        XCTAssertNotNil(store.season(id: season.id))

        let look = try XCTUnwrap(season.looks.first)
        XCTAssertEqual(store.look(id: look.id)?.season.id, season.id)

        let item = try XCTUnwrap(look.items.first)
        XCTAssertEqual(store.placement(ofItem: item.id)?.look.id, look.id)
    }

    /// Суммарный вес гардероба равен сумме весов всех вещей.
    func testTotalWeightIsSumOfItems() {
        let expected = store.allPlacements.reduce(0) { $0 + $1.item.weightGrams }
        XCTAssertEqual(store.totalWeightGrams, expected)
    }

    /// Форматирование веса переключается между граммами и килограммами.
    func testWeightFormatting() {
        XCTAssertEqual(WeightFormatter.string(grams: 180), "180 г")
        XCTAssertEqual(WeightFormatter.string(grams: 1450), "1,45 кг")
    }
}
