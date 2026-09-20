import Foundation

/// Статус вещи в жизненном цикле гардероба.
enum ItemStatus: String, CaseIterable, Identifiable, Hashable {
    case inCloset
    case inTrip
    case inLaundry

    var id: String { rawValue }

    /// Название статуса для интерфейса.
    var title: String {
        switch self {
        case .inCloset:  return "В шкафу"
        case .inTrip:    return "В поездке"
        case .inLaundry: return "В стирке"
        }
    }

    /// Имя системного символа SF Symbols.
    var icon: String {
        switch self {
        case .inCloset:  return "archivebox"
        case .inTrip:    return "airplane"
        case .inLaundry: return "washer"
        }
    }
}

/// Конкретная вещь гардероба — нижний уровень иерархии.
struct WardrobeItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var icon: String
    /// Вес вещи в граммах: на нём строится расчёт веса багажа.
    var weightGrams: Int
    var status: ItemStatus
    var note: String

    init(id: UUID = UUID(),
         name: String,
         category: String,
         icon: String,
         weightGrams: Int,
         status: ItemStatus = .inCloset,
         note: String = "") {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.weightGrams = weightGrams
        self.status = status
        self.note = note
    }
}

/// Образ — набор вещей, средний уровень иерархии.
struct Look: Identifiable, Hashable {
    let id: UUID
    var name: String
    var occasion: String
    var items: [WardrobeItem]

    init(id: UUID = UUID(), name: String, occasion: String, items: [WardrobeItem] = []) {
        self.id = id
        self.name = name
        self.occasion = occasion
        self.items = items
    }

    var totalWeightGrams: Int { items.reduce(0) { $0 + $1.weightGrams } }
}

/// Сезон/стиль — верхний уровень структуры хранения вещей.
struct SeasonStyle: Identifiable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var looks: [Look]

    init(id: UUID = UUID(), name: String, icon: String, looks: [Look] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.looks = looks
    }

    var itemCount: Int { looks.reduce(0) { $0 + $1.items.count } }
    var totalWeightGrams: Int { looks.reduce(0) { $0 + $1.totalWeightGrams } }
}

/// Результат поиска: вещь вместе с её местом в иерархии «Сезон/Стиль → Образ».
struct ItemPlacement: Identifiable, Hashable {
    let season: SeasonStyle
    let look: Look
    let item: WardrobeItem

    var id: UUID { item.id }
    var path: String { "\(season.name) → \(look.name)" }
}

/// Маршруты навигации приложения.
enum Route: Hashable {
    case season(SeasonStyle.ID)
    case look(Look.ID)
    case item(WardrobeItem.ID)
}

/// Форматирование веса: граммы → строка вида «1,25 кг» или «450 г».
enum WeightFormatter {
    static func string(grams: Int) -> String {
        if grams < 1000 {
            return "\(grams) г"
        }
        let kilograms = Double(grams) / 1000.0
        return String(format: "%.2f кг", kilograms)
            .replacingOccurrences(of: ".", with: ",")
    }
}
