import Foundation
import Observation
import SwiftData

/// Реализация хранилища поверх SwiftData.
///
/// Подставляется вместо `WardrobeStore` без единой правки моделей
/// представления и экранов: оба класса реализуют одни и те же протоколы
/// `WardrobeProviding` и `TripStoring`.
///
/// Сущности базы данных наружу не выдаются: репозиторий отображает их
/// в доменные структуры `SeasonStyle`, `Look`, `WardrobeItem` и `Trip`,
/// а закэшированные снимки `seasons` и `trips` помечены как наблюдаемые,
/// поэтому SwiftUI перерисовывает экраны после каждого изменения базы.
@Observable
final class SwiftDataRepository: WardrobeProviding, TripStoring {

    @ObservationIgnored private let context: ModelContext

    private(set) var seasons: [SeasonStyle] = []
    private(set) var trips: [Trip] = []
    /// Отчёт последней синхронизации каталога — выводится на экране настроек.
    private(set) var lastSyncReport: SyncReport?

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    // MARK: - Чтение базы и отображение в доменные модели

    /// Перечитывает базу данных и обновляет наблюдаемые снимки.
    func reload() {
        seasons = fetchSeasons()
        trips = fetchTrips()
    }

    private func fetchSeasons() -> [SeasonStyle] {
        let descriptor = FetchDescriptor<SeasonEntity>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)])
        let entities = (try? context.fetch(descriptor)) ?? []

        return entities.map { season in
            SeasonStyle(id: season.id,
                        name: season.name,
                        icon: season.icon,
                        looks: season.looks
                            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
                            .map { look in
                                Look(id: look.id,
                                     name: look.name,
                                     occasion: look.occasion,
                                     items: look.items
                                        .sorted { $0.createdAt < $1.createdAt }
                                        .map(Self.makeItem))
                            })
        }
    }

    private static func makeItem(_ entity: ItemEntity) -> WardrobeItem {
        WardrobeItem(id: entity.id,
                     name: entity.name,
                     category: entity.category,
                     icon: entity.icon,
                     weightGrams: entity.weightGrams,
                     status: entity.status,
                     note: entity.note)
    }

    private func fetchTrips() -> [Trip] {
        let descriptor = FetchDescriptor<TripEntity>(sortBy: [SortDescriptor(\.startDate)])
        let entities = (try? context.fetch(descriptor)) ?? []

        return entities.map { trip in
            Trip(id: trip.id,
                 title: trip.title,
                 destination: trip.destination,
                 kind: trip.kind,
                 startDate: trip.startDate,
                 endDate: trip.endDate,
                 limitGrams: trip.limitGrams,
                 items: trip.items
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { packed in
                        PackedItem(id: packed.id,
                                   item: WardrobeItem(id: packed.itemID,
                                                      name: packed.name,
                                                      category: packed.category,
                                                      icon: packed.icon,
                                                      weightGrams: packed.weightGrams),
                                   quantity: packed.quantity,
                                   isPacked: packed.isPacked,
                                   source: packed.source)
                    })
        }
    }

    // MARK: - WardrobeProviding

    var allPlacements: [ItemPlacement] {
        seasons.flatMap { season in
            season.looks.flatMap { look in
                look.items.map { ItemPlacement(season: season, look: look, item: $0) }
            }
        }
    }

    func count(of status: ItemStatus) -> Int {
        allPlacements.filter { $0.item.status == status }.count
    }

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

    func setStatus(_ status: ItemStatus, forItem id: WardrobeItem.ID) {
        guard let entity = fetchItem(id: id) else { return }
        entity.status = status
        save()
    }

    private func fetchItem(id: UUID) -> ItemEntity? {
        var descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchTripEntity(id: UUID) -> TripEntity? {
        var descriptor = FetchDescriptor<TripEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - TripStoring

    func trip(id: Trip.ID) -> Trip? {
        trips.first { $0.id == id }
    }

    func save(_ trip: Trip) {
        let entity: TripEntity
        if let existing = fetchTripEntity(id: trip.id) {
            entity = existing
            entity.title = trip.title
            entity.destination = trip.destination
            entity.kind = trip.kind
            entity.startDate = trip.startDate
            entity.endDate = trip.endDate
            entity.limitGrams = trip.limitGrams
            // Вещи чемодана пересобираются: каскадное правило удаляет
            // отвязанные записи PackedItemEntity автоматически.
            for packed in entity.items {
                context.delete(packed)
            }
            entity.items.removeAll()
        } else {
            entity = TripEntity(id: trip.id,
                                title: trip.title,
                                destination: trip.destination,
                                kind: trip.kind,
                                startDate: trip.startDate,
                                endDate: trip.endDate,
                                limitGrams: trip.limitGrams)
            context.insert(entity)
        }

        for (index, packed) in trip.items.enumerated() {
            let packedEntity = PackedItemEntity(id: packed.id,
                                                itemID: packed.item.id,
                                                name: packed.item.name,
                                                category: packed.item.category,
                                                icon: packed.item.icon,
                                                weightGrams: packed.item.weightGrams,
                                                quantity: packed.quantity,
                                                isPacked: packed.isPacked,
                                                source: packed.source,
                                                sortOrder: index)
            context.insert(packedEntity)
            packedEntity.trip = entity
        }

        save()
    }

    func delete(tripID: Trip.ID) {
        guard let entity = fetchTripEntity(id: tripID) else { return }
        context.delete(entity)
        save()
    }

    // MARK: - Синхронизация каталога

    /// Наполняет базу начальными данными каталога, не теряя
    /// добавленное пользователем в предыдущих сеансах.
    @discardableResult
    func synchronize(with catalog: CatalogDTO) throws -> SyncReport {
        let report = try CatalogSyncService().sync(catalog, into: context)
        lastSyncReport = report
        reload()
        return report
    }

    /// Создаёт демонстрационные поездки. Вызывается один раз — при первом
    /// запуске приложения, что определяется маркером в UserDefaults.
    func seedDemoTrips() {
        guard trips.isEmpty else { return }

        let byName = Dictionary(allPlacements.map { ($0.item.name, $0.item) },
                                uniquingKeysWith: { first, _ in first })

        func pack(_ specification: [(String, Int)]) -> [PackedItem] {
            specification.compactMap { name, quantity in
                guard let item = byName[name] else { return nil }
                return PackedItem(item: item, quantity: quantity)
            }
        }

        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = 12
            return Calendar(identifier: .gregorian).date(from: components) ?? .now
        }

        let demo = [
            Trip(title: "Отпуск на море", destination: "Батуми", kind: .beach,
                 startDate: date(2026, 10, 3), endDate: date(2026, 10, 10),
                 limitGrams: BaggageLimit.cabin.grams,
                 items: pack([("Плавки", 3), ("Рубашка льняная", 2),
                              ("Полотенце пляжное", 1), ("Сланцы", 1)])),
            Trip(title: "Конференция", destination: "Вильнюс", kind: .business,
                 startDate: date(2026, 11, 12), endDate: date(2026, 11, 15),
                 limitGrams: BaggageLimit.cabin.grams,
                 items: pack([("Пиджак шерстяной", 1), ("Брюки классические", 1),
                              ("Чиносы бежевые", 1), ("Лоферы", 1)])),
            Trip(title: "Горнолыжная неделя", destination: "Буковель", kind: .mountains,
                 startDate: date(2026, 12, 20), endDate: date(2026, 12, 27),
                 limitGrams: BaggageLimit.checked.grams,
                 items: pack([("Пуховик", 1), ("Термобельё", 2),
                              ("Свитер шерстяной", 1)]))
        ]

        for trip in demo {
            save(trip)
        }
    }

    // MARK: - Сохранение

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Не удалось сохранить контекст: \(error)")
        }
        reload()
    }
}
