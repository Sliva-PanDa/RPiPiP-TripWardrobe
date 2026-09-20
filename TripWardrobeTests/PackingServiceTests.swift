import XCTest
@testable import TripWardrobe

/// Тесты алгоритма автоматического формирования базового списка вещей.
final class PackingServiceTests: XCTestCase {

    private var service: RuleBasedPackingService!
    private var wardrobe: [ItemPlacement]!

    override func setUp() {
        super.setUp()
        service = RuleBasedPackingService()
        wardrobe = WardrobeStore().allPlacements
    }

    override func tearDown() {
        service = nil
        wardrobe = nil
        super.tearDown()
    }

    private func trip(kind: TripKind, nights: Int, city: String = "Гомель") -> Trip {
        let start = Date()
        return Trip(title: "Тест",
                    destination: city,
                    kind: kind,
                    startDate: start,
                    endDate: Calendar.current.date(byAdding: .day, value: nights, to: start)!,
                    limitGrams: BaggageLimit.checked.grams)
    }

    /// Для пляжной поездки базовый набор включает верх, низ и обувь.
    func testBeachBaseListCoversMainCategories() {
        let result = service.suggestions(for: trip(kind: .beach, nights: 7),
                                         weather: nil,
                                         wardrobe: wardrobe)
        let categories = Set(result.map(\.item.category))

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(categories.contains("Верх"))
        XCTAssertTrue(categories.contains("Низ"))
        XCTAssertTrue(categories.contains("Обувь"))
    }

    /// Деловая поездка отличается по составу от пляжной.
    func testBusinessListDiffersFromBeach() {
        let beach = service.suggestions(for: trip(kind: .beach, nights: 5),
                                        weather: nil, wardrobe: wardrobe)
        let business = service.suggestions(for: trip(kind: .business, nights: 5),
                                           weather: nil, wardrobe: wardrobe)

        XCTAssertNotEqual(Set(beach.map(\.item.id)), Set(business.map(\.item.id)))
    }

    /// Чем длиннее поездка, тем больше комплектов одежды.
    func testLongerTripNeedsMoreItems() {
        let short = service.suggestions(for: trip(kind: .beach, nights: 2),
                                        weather: nil, wardrobe: wardrobe)
        let long = service.suggestions(for: trip(kind: .beach, nights: 10),
                                       weather: nil, wardrobe: wardrobe)

        let shortTotal = short.reduce(0) { $0 + $1.quantity }
        let longTotal = long.reduce(0) { $0 + $1.quantity }
        XCTAssertGreaterThan(longTotal, shortTotal)
    }

    /// Холодная погода увеличивает количество вещей верхнего слоя.
    func testColdWeatherAddsWarmLayer() {
        let cold = WeatherSnapshot(city: "Буковель", minTemperature: -9,
                                   maxTemperature: -1, precipitationProbability: 10)
        let mild = WeatherSnapshot(city: "Гомель", minTemperature: 14,
                                   maxTemperature: 20, precipitationProbability: 10)

        let withCold = service.suggestions(for: trip(kind: .mountains, nights: 6),
                                           weather: cold, wardrobe: wardrobe)
        let withMild = service.suggestions(for: trip(kind: .mountains, nights: 6),
                                           weather: mild, wardrobe: wardrobe)

        func tops(_ list: [PackingSuggestion]) -> Int {
            list.filter { $0.item.category == "Верх" }.reduce(0) { $0 + $1.quantity }
        }
        XCTAssertGreaterThan(tops(withCold), tops(withMild))
    }

    /// При высокой вероятности осадков предлагается дополнительная обувь,
    /// а обоснование упоминает осадки.
    func testRainyWeatherAddsShoesWithReason() {
        let rainy = WeatherSnapshot(city: "Вильнюс", minTemperature: 12,
                                    maxTemperature: 18, precipitationProbability: 70)
        let result = service.suggestions(for: trip(kind: .business, nights: 4),
                                         weather: rainy, wardrobe: wardrobe)
        let shoes = result.filter { $0.item.category == "Обувь" }

        XCTAssertFalse(shoes.isEmpty)
        XCTAssertTrue(shoes.contains { $0.reason.contains("Осадки") })
    }

    /// Вещи, уже лежащие в чемодане, повторно не предлагаются.
    func testAlreadyPackedItemsAreNotSuggested() throws {
        var target = trip(kind: .beach, nights: 5)
        let packedItem = try XCTUnwrap(wardrobe.first { $0.item.category == "Обувь" }).item
        target.items = [PackedItem(item: packedItem)]

        let result = service.suggestions(for: target, weather: nil, wardrobe: wardrobe)
        XCTAssertFalse(result.contains { $0.item.id == packedItem.id })
    }

    /// В обосновании базового набора указывается тип поездки.
    func testReasonMentionsTripKind() {
        let result = service.suggestions(for: trip(kind: .mountains, nights: 3),
                                         weather: nil, wardrobe: wardrobe)
        XCTAssertTrue(result.contains { $0.reason.contains("Горы") })
    }

    /// Пустой гардероб не приводит к падению алгоритма.
    func testEmptyWardrobeProducesNoSuggestions() {
        let result = service.suggestions(for: trip(kind: .beach, nights: 4),
                                         weather: nil, wardrobe: [])
        XCTAssertTrue(result.isEmpty)
    }
}
