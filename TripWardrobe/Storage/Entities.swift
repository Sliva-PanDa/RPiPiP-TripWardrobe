import Foundation
import SwiftData

/// Происхождение записи: пришла из каталога сервера или создана пользователем.
/// От этого зависит поведение при синхронизации: пользовательские записи
/// при обновлении каталога никогда не удаляются.
enum RecordOrigin: String, Codable {
    case remote
    case local
}

// MARK: - Вещь

/// Вещь гардероба — нижний уровень иерархии хранения.
@Model
final class ItemEntity {
    @Attribute(.unique) var id: UUID
    /// Идентификатор записи в каталоге сервера; nil — у вещей, добавленных пользователем.
    var remoteID: String?
    var name: String
    var category: String
    var icon: String
    var weightGrams: Int
    /// Статус хранится строкой: SwiftData не умеет напрямую работать с перечислениями.
    var statusRaw: String
    var note: String
    var originRaw: String
    var createdAt: Date

    /// Обратная связь «многие к одному» с образом.
    var look: LookEntity?

    init(id: UUID = UUID(),
         remoteID: String? = nil,
         name: String,
         category: String,
         icon: String,
         weightGrams: Int,
         status: ItemStatus = .inCloset,
         note: String = "",
         origin: RecordOrigin = .local,
         createdAt: Date = .now) {
        self.id = id
        self.remoteID = remoteID
        self.name = name
        self.category = category
        self.icon = icon
        self.weightGrams = weightGrams
        self.statusRaw = status.rawValue
        self.note = note
        self.originRaw = origin.rawValue
        self.createdAt = createdAt
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .inCloset }
        set { statusRaw = newValue.rawValue }
    }

    var origin: RecordOrigin {
        get { RecordOrigin(rawValue: originRaw) ?? .local }
        set { originRaw = newValue.rawValue }
    }
}

// MARK: - Образ

/// Образ — набор вещей, средний уровень иерархии.
@Model
final class LookEntity {
    @Attribute(.unique) var id: UUID
    var remoteID: String?
    var name: String
    var occasion: String
    var sortOrder: Int
    var originRaw: String

    var season: SeasonEntity?

    /// Связь «один ко многим». Каскадное удаление: вместе с образом
    /// из базы исчезают все входящие в него вещи.
    @Relationship(deleteRule: .cascade, inverse: \ItemEntity.look)
    var items: [ItemEntity] = []

    init(id: UUID = UUID(),
         remoteID: String? = nil,
         name: String,
         occasion: String,
         sortOrder: Int = 0,
         origin: RecordOrigin = .local) {
        self.id = id
        self.remoteID = remoteID
        self.name = name
        self.occasion = occasion
        self.sortOrder = sortOrder
        self.originRaw = origin.rawValue
    }

    var origin: RecordOrigin {
        get { RecordOrigin(rawValue: originRaw) ?? .local }
        set { originRaw = newValue.rawValue }
    }
}

// MARK: - Сезон/стиль

/// Сезон или стиль — верхний уровень структуры хранения.
@Model
final class SeasonEntity {
    @Attribute(.unique) var id: UUID
    var remoteID: String?
    var name: String
    var icon: String
    var sortOrder: Int
    var originRaw: String

    @Relationship(deleteRule: .cascade, inverse: \LookEntity.season)
    var looks: [LookEntity] = []

    init(id: UUID = UUID(),
         remoteID: String? = nil,
         name: String,
         icon: String,
         sortOrder: Int = 0,
         origin: RecordOrigin = .local) {
        self.id = id
        self.remoteID = remoteID
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.originRaw = origin.rawValue
    }

    var origin: RecordOrigin {
        get { RecordOrigin(rawValue: originRaw) ?? .local }
        set { originRaw = newValue.rawValue }
    }
}

// MARK: - Чемодан

/// Вещь, уложенная в чемодан. Хранит копию характеристик вещи,
/// поэтому правка гардероба не меняет задним числом собранный багаж.
@Model
final class PackedItemEntity {
    @Attribute(.unique) var id: UUID
    var itemID: UUID
    var name: String
    var category: String
    var icon: String
    var weightGrams: Int
    var quantity: Int
    var isPacked: Bool
    var sourceRaw: String
    var sortOrder: Int

    var trip: TripEntity?

    init(id: UUID = UUID(),
         itemID: UUID,
         name: String,
         category: String,
         icon: String,
         weightGrams: Int,
         quantity: Int = 1,
         isPacked: Bool = false,
         source: PackSource = .manual,
         sortOrder: Int = 0) {
        self.id = id
        self.itemID = itemID
        self.name = name
        self.category = category
        self.icon = icon
        self.weightGrams = weightGrams
        self.quantity = quantity
        self.isPacked = isPacked
        self.sourceRaw = source.rawValue
        self.sortOrder = sortOrder
    }

    var source: PackSource {
        get { PackSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

/// Поездка (чемодан) — запись, созданная пользователем.
/// При обновлении каталога с сервера поездки не затрагиваются.
@Model
final class TripEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var destination: String
    var kindRaw: String
    var startDate: Date
    var endDate: Date
    var limitGrams: Int

    @Relationship(deleteRule: .cascade, inverse: \PackedItemEntity.trip)
    var items: [PackedItemEntity] = []

    init(id: UUID = UUID(),
         title: String,
         destination: String,
         kind: TripKind,
         startDate: Date,
         endDate: Date,
         limitGrams: Int) {
        self.id = id
        self.title = title
        self.destination = destination
        self.kindRaw = kind.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.limitGrams = limitGrams
    }

    var kind: TripKind {
        get { TripKind(rawValue: kindRaw) ?? .beach }
        set { kindRaw = newValue.rawValue }
    }
}
