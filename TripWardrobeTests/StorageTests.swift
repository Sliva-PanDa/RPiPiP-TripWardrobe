import XCTest
import SwiftUI
import SwiftData
@testable import TripWardrobe

/// Тесты слоя хранения: база данных SwiftData и синхронизация каталога.
final class StorageTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: SwiftDataRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([SeasonEntity.self, LookEntity.self, ItemEntity.self,
                             TripEntity.self, PackedItemEntity.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        context = ModelContext(container)
        repository = SwiftDataRepository(context: context)
    }

    override func tearDown() {
        repository = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Вспомогательные каталоги

    private func catalog(from json: String) throws -> CatalogDTO {
        try JSONDecoder.catalog.decode(CatalogDTO.self, from: Data(json.utf8))
    }

    private var baseCatalogJSON: String {
        """
        {
          "version": 1,
          "updated_at": "2026-09-01T09:00:00Z",
          "seasons": [
            {
              "season_id": "s1", "title": "Лето", "icon": "sun.max",
              "looks": [
                {
                  "look_id": "l1", "title": "Пляж", "occasion": "Отдых",
                  "items": [
                    { "item_id": "i1", "title": "Плавки", "category": "Низ",
                      "icon": "drop", "weight_grams": 120, "status": "inTrip" },
                    { "item_id": "i2", "title": "Сланцы", "category": "Обувь",
                      "icon": "figure.walk", "weight_grams": 310 }
                  ]
                }
              ]
            }
          ]
        }
        """
    }

    // MARK: - Разбор каталога

    /// Ключи JSON в стиле snake_case сопоставляются со свойствами через CodingKeys.
    func testCatalogDecodingMapsSnakeCaseKeys() throws {
        let catalog = try catalog(from: baseCatalogJSON)

        XCTAssertEqual(catalog.version, 1)
        XCTAssertNotNil(catalog.updatedAt)
        XCTAssertEqual(catalog.seasons.first?.id, "s1")
        XCTAssertEqual(catalog.seasons.first?.name, "Лето")
        XCTAssertEqual(catalog.seasons.first?.looks.first?.items.first?.weightGrams, 120)
        XCTAssertEqual(catalog.seasons.first?.looks.first?.items.first?.initialStatus, .inTrip)
        XCTAssertEqual(catalog.seasons.first?.looks.first?.items.last?.initialStatus, .inCloset)
    }

    /// Каталог из ресурсов приложения читается и содержит все сезоны.
    func testBundledCatalogIsReadable() async throws {
        let provider = BundleCatalogProvider(bundle: Bundle(for: Self.self))
        // В тестовом бандле ресурса может не быть — тогда берём основной бандл.
        let catalog = (try? await provider.loadCatalog())
            ?? (try await BundleCatalogProvider(bundle: .main).loadCatalog())

        XCTAssertEqual(catalog.seasons.count, 3)
        let items = catalog.seasons.flatMap { $0.looks.flatMap(\.items) }
        XCTAssertEqual(items.count, 24)
    }

    // MARK: - Наполнение пустой базы

    /// Изначально пустая база наполняется каталогом при первой синхронизации.
    func testEmptyDatabaseIsFilledFromCatalog() throws {
        XCTAssertTrue(repository.seasons.isEmpty)

        let report = try repository.synchronize(with: try catalog(from: baseCatalogJSON))

        XCTAssertEqual(repository.seasons.count, 1)
        XCTAssertEqual(repository.allPlacements.count, 2)
        XCTAssertEqual(report.inserted, 4)   // сезон + образ + две вещи
        XCTAssertEqual(report.updated, 0)
    }

    /// Повторная синхронизация тем же каталогом не создаёт дубликатов.
    func testRepeatedSyncDoesNotDuplicate() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        let report = try repository.synchronize(with: try catalog(from: baseCatalogJSON))

        XCTAssertEqual(repository.seasons.count, 1)
        XCTAssertEqual(repository.allPlacements.count, 2)
        XCTAssertEqual(report.inserted, 0)
        XCTAssertEqual(report.updated, 4)
    }

    // MARK: - Сохранность пользовательских данных

    /// Статус, выставленный пользователем, при обновлении каталога не сбрасывается.
    func testUserStatusSurvivesCatalogUpdate() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        let item = try XCTUnwrap(repository.allPlacements.first { $0.item.name == "Сланцы" })
        XCTAssertEqual(item.item.status, .inCloset)

        repository.setStatus(.inLaundry, forItem: item.item.id)
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))

        let reloaded = try XCTUnwrap(repository.placement(ofItem: item.item.id))
        XCTAssertEqual(reloaded.item.status, .inLaundry)
    }

    /// Обновление каталога меняет справочные поля вещи.
    func testCatalogUpdateChangesReferenceFields() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))

        let updated = baseCatalogJSON.replacingOccurrences(
            of: "\"weight_grams\": 310", with: "\"weight_grams\": 400")
        try repository.synchronize(with: try catalog(from: updated))

        let item = try XCTUnwrap(repository.allPlacements.first { $0.item.name == "Сланцы" })
        XCTAssertEqual(item.item.weightGrams, 400)
    }

    /// Вещь, исчезнувшая из каталога, удаляется из базы.
    func testItemRemovedFromCatalogIsDeleted() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        XCTAssertEqual(repository.allPlacements.count, 2)

        let shortened = """
        {
          "version": 2,
          "seasons": [
            {
              "season_id": "s1", "title": "Лето", "icon": "sun.max",
              "looks": [
                {
                  "look_id": "l1", "title": "Пляж", "occasion": "Отдых",
                  "items": [
                    { "item_id": "i1", "title": "Плавки", "category": "Низ",
                      "icon": "drop", "weight_grams": 120 }
                  ]
                }
              ]
            }
          ]
        }
        """
        let report = try repository.synchronize(with: try catalog(from: shortened))

        XCTAssertEqual(repository.allPlacements.count, 1)
        XCTAssertEqual(report.removed, 1)
    }

    /// Поездки, созданные пользователем, при обновлении каталога сохраняются.
    func testTripsSurviveCatalogUpdate() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        let item = try XCTUnwrap(repository.allPlacements.first).item

        let trip = Trip(title: "Отпуск", destination: "Батуми", kind: .beach,
                        startDate: .now, endDate: .now.addingTimeInterval(86_400 * 5),
                        limitGrams: BaggageLimit.cabin.grams,
                        items: [PackedItem(item: item, quantity: 2)])
        repository.save(trip)
        XCTAssertEqual(repository.trips.count, 1)

        try repository.synchronize(with: try catalog(from: baseCatalogJSON))

        XCTAssertEqual(repository.trips.count, 1)
        XCTAssertEqual(repository.trip(id: trip.id)?.items.first?.quantity, 2)
        XCTAssertEqual(repository.trip(id: trip.id)?.totalWeightGrams, item.weightGrams * 2)
    }

    // MARK: - Поездки

    /// Повторное сохранение поездки обновляет запись, а не создаёт новую.
    func testSavingTripTwiceUpdatesRecord() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        let item = try XCTUnwrap(repository.allPlacements.first).item

        var trip = Trip(title: "Поездка", destination: "Гомель", kind: .business,
                        startDate: .now, endDate: .now.addingTimeInterval(86_400 * 3),
                        limitGrams: 10_000,
                        items: [PackedItem(item: item)])
        repository.save(trip)

        trip.limitGrams = 23_000
        trip.items[0].isPacked = true
        repository.save(trip)

        XCTAssertEqual(repository.trips.count, 1)
        XCTAssertEqual(repository.trip(id: trip.id)?.limitGrams, 23_000)
        XCTAssertEqual(repository.trip(id: trip.id)?.packedCount, 1)
    }

    /// Каскадное удаление: вместе с поездкой исчезают её упакованные вещи.
    func testDeletingTripCascadesToPackedItems() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        let item = try XCTUnwrap(repository.allPlacements.first).item
        let trip = Trip(title: "Поездка", destination: "Гомель", kind: .beach,
                        startDate: .now, endDate: .now.addingTimeInterval(86_400),
                        limitGrams: 10_000,
                        items: [PackedItem(item: item), PackedItem(item: item)])
        repository.save(trip)

        repository.delete(tripID: trip.id)

        XCTAssertTrue(repository.trips.isEmpty)
        let remaining = try context.fetch(FetchDescriptor<PackedItemEntity>())
        XCTAssertTrue(remaining.isEmpty)
    }

    /// Каскадное удаление: вместе с образом удаляются входящие в него вещи.
    func testDeletingLookCascadesToItems() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))
        let look = try XCTUnwrap(context.fetch(FetchDescriptor<LookEntity>()).first)

        context.delete(look)
        try context.save()
        repository.reload()

        XCTAssertTrue(repository.allPlacements.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ItemEntity>()).isEmpty)
    }

    /// Демонстрационные поездки создаются один раз.
    func testDemoTripsAreSeededOnce() throws {
        try repository.synchronize(with: try catalog(from: baseCatalogJSON))

        repository.seedDemoTrips()
        let afterFirst = repository.trips.count
        repository.seedDemoTrips()

        XCTAssertEqual(repository.trips.count, afterFirst)
    }
}

/// Тесты вспомогательного хранилища настроек в UserDefaults.
final class AppSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "TripWardrobeTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// На чистом хранилище берутся значения по умолчанию.
    func testDefaultValues() {
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.defaultLimitGrams, BaggageLimit.checked.grams)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertFalse(settings.hasCompletedFirstLaunch)
        XCTAssertNil(settings.appearance.colorScheme)
    }

    /// Изменения сразу записываются в UserDefaults и переживают перезапуск.
    func testValuesArePersisted() {
        let settings = AppSettings(defaults: defaults)
        settings.defaultLimitGrams = BaggageLimit.cabin.grams
        settings.appearance = .dark
        settings.hasCompletedFirstLaunch = true

        // Новый экземпляр читает те же значения из хранилища.
        let restored = AppSettings(defaults: defaults)

        XCTAssertEqual(restored.defaultLimitGrams, BaggageLimit.cabin.grams)
        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertTrue(restored.hasCompletedFirstLaunch)
        XCTAssertEqual(restored.defaultLimitTitle, "10,00 кг")
    }

    /// Сброс возвращает значения по умолчанию и очищает ключи.
    func testResetRestoresDefaults() {
        let settings = AppSettings(defaults: defaults)
        settings.appearance = .light
        settings.hasCompletedFirstLaunch = true

        settings.reset()

        XCTAssertEqual(settings.appearance, .system)
        XCTAssertFalse(settings.hasCompletedFirstLaunch)
        XCTAssertEqual(AppSettings(defaults: defaults).appearance, .system)
    }

    /// Каждой теме соответствует своя цветовая схема.
    func testAppearanceColorSchemes() {
        XCTAssertNil(AppSettings.Appearance.system.colorScheme)
        XCTAssertEqual(AppSettings.Appearance.light.colorScheme, .light)
        XCTAssertEqual(AppSettings.Appearance.dark.colorScheme, .dark)
    }
}
