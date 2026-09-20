import Foundation
import SwiftData

/// Результат синхронизации каталога — используется для отчёта в интерфейсе.
struct SyncReport: Equatable {
    var inserted = 0
    var updated = 0
    var removed = 0
    var preserved = 0

    var summary: String {
        "добавлено \(inserted), обновлено \(updated), удалено \(removed), "
            + "сохранено пользовательских \(preserved)"
    }
}

/// Источник каталога начальных данных.
protocol CatalogProviding: AnyObject {
    func loadCatalog() async throws -> CatalogDTO
}

/// Чтение каталога из ресурсов приложения.
/// В лабораторной работе № 4 будет заменено на загрузку по REST API.
final class BundleCatalogProvider: CatalogProviding {
    private let resourceName: String
    private let bundle: Bundle

    init(resourceName: String = "catalog", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func loadCatalog() async throws -> CatalogDTO {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CatalogError.resourceNotFound(resourceName)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.catalog.decode(CatalogDTO.self, from: data)
    }
}

enum CatalogError: LocalizedError {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Файл каталога \(name).json не найден в ресурсах приложения"
        }
    }
}

/// Слияние каталога с базой данных.
///
/// База изначально пуста и наполняется каталогом при каждом старте приложения.
/// Правило слияния: записи сопоставляются по `remoteID`; существующие
/// обновляются справочными полями (название, категория, вес, значок),
/// пользовательские поля (статус, заметка) сохраняются. Записи, созданные
/// пользователем, и все поездки при синхронизации не затрагиваются.
struct CatalogSyncService {

    @discardableResult
    func sync(_ catalog: CatalogDTO, into context: ModelContext) throws -> SyncReport {
        var report = SyncReport()

        let existingSeasons = try context.fetch(FetchDescriptor<SeasonEntity>())
        var seasonsByRemoteID = Dictionary(
            uniqueKeysWithValues: existingSeasons
                .compactMap { entity -> (String, SeasonEntity)? in
                    guard let remoteID = entity.remoteID else { return nil }
                    return (remoteID, entity)
                })

        let existingLooks = try context.fetch(FetchDescriptor<LookEntity>())
        var looksByRemoteID = Dictionary(
            uniqueKeysWithValues: existingLooks
                .compactMap { entity -> (String, LookEntity)? in
                    guard let remoteID = entity.remoteID else { return nil }
                    return (remoteID, entity)
                })

        let existingItems = try context.fetch(FetchDescriptor<ItemEntity>())
        var itemsByRemoteID = Dictionary(
            uniqueKeysWithValues: existingItems
                .compactMap { entity -> (String, ItemEntity)? in
                    guard let remoteID = entity.remoteID else { return nil }
                    return (remoteID, entity)
                })

        report.preserved = existingItems.filter { $0.origin == .local }.count

        // Идентификаторы, присутствующие в каталоге: всё остальное
        // серверного происхождения считается удалённым на сервере.
        var catalogSeasonIDs = Set<String>()
        var catalogLookIDs = Set<String>()
        var catalogItemIDs = Set<String>()

        for (seasonIndex, seasonDTO) in catalog.seasons.enumerated() {
            catalogSeasonIDs.insert(seasonDTO.id)

            let season: SeasonEntity
            if let existing = seasonsByRemoteID[seasonDTO.id] {
                existing.name = seasonDTO.name
                existing.icon = seasonDTO.icon
                existing.sortOrder = seasonIndex
                season = existing
                report.updated += 1
            } else {
                season = SeasonEntity(remoteID: seasonDTO.id,
                                      name: seasonDTO.name,
                                      icon: seasonDTO.icon,
                                      sortOrder: seasonIndex,
                                      origin: .remote)
                context.insert(season)
                seasonsByRemoteID[seasonDTO.id] = season
                report.inserted += 1
            }

            for (lookIndex, lookDTO) in seasonDTO.looks.enumerated() {
                catalogLookIDs.insert(lookDTO.id)

                let look: LookEntity
                if let existing = looksByRemoteID[lookDTO.id] {
                    existing.name = lookDTO.name
                    existing.occasion = lookDTO.occasion
                    existing.sortOrder = lookIndex
                    existing.season = season
                    look = existing
                    report.updated += 1
                } else {
                    look = LookEntity(remoteID: lookDTO.id,
                                      name: lookDTO.name,
                                      occasion: lookDTO.occasion,
                                      sortOrder: lookIndex,
                                      origin: .remote)
                    context.insert(look)
                    look.season = season
                    looksByRemoteID[lookDTO.id] = look
                    report.inserted += 1
                }

                for itemDTO in lookDTO.items {
                    catalogItemIDs.insert(itemDTO.id)

                    if let existing = itemsByRemoteID[itemDTO.id] {
                        // Справочные поля обновляются, пользовательские — нет.
                        existing.name = itemDTO.name
                        existing.category = itemDTO.category
                        existing.icon = itemDTO.icon
                        existing.weightGrams = itemDTO.weightGrams
                        existing.look = look
                        report.updated += 1
                    } else {
                        let item = ItemEntity(remoteID: itemDTO.id,
                                              name: itemDTO.name,
                                              category: itemDTO.category,
                                              icon: itemDTO.icon,
                                              weightGrams: itemDTO.weightGrams,
                                              status: itemDTO.initialStatus,
                                              note: itemDTO.note ?? "",
                                              origin: .remote)
                        context.insert(item)
                        item.look = look
                        itemsByRemoteID[itemDTO.id] = item
                        report.inserted += 1
                    }
                }
            }
        }

        // Удаление записей, исчезнувших из каталога. Пользовательские записи
        // (origin == .local) и поездки при этом не затрагиваются.
        for item in existingItems where item.origin == .remote {
            if let remoteID = item.remoteID, !catalogItemIDs.contains(remoteID) {
                context.delete(item)
                report.removed += 1
            }
        }
        for look in existingLooks where look.origin == .remote {
            if let remoteID = look.remoteID, !catalogLookIDs.contains(remoteID) {
                context.delete(look)
                report.removed += 1
            }
        }
        for season in existingSeasons where season.origin == .remote {
            if let remoteID = season.remoteID, !catalogSeasonIDs.contains(remoteID) {
                context.delete(season)
                report.removed += 1
            }
        }

        try context.save()
        return report
    }
}
