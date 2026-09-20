import Foundation

/// Тип поездки: определяет базовый набор вещей при автоматической сборке.
enum TripKind: String, CaseIterable, Identifiable, Hashable {
    case beach
    case business
    case mountains

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beach:     return "Пляж"
        case .business:  return "Бизнес"
        case .mountains: return "Горы"
        }
    }

    var icon: String {
        switch self {
        case .beach:     return "beach.umbrella"
        case .business:  return "briefcase"
        case .mountains: return "mountain.2"
        }
    }
}

/// Предустановленные лимиты веса багажа авиакомпаний.
enum BaggageLimit: Int, CaseIterable, Identifiable, Hashable {
    /// Ручная кладь — 10 кг.
    case cabin = 10_000
    /// Зарегистрированный багаж — 23 кг.
    case checked = 23_000

    var id: Int { rawValue }
    var grams: Int { rawValue }

    var title: String {
        switch self {
        case .cabin:   return "Ручная кладь · 10 кг"
        case .checked: return "Багаж · 23 кг"
        }
    }

    var shortTitle: String {
        switch self {
        case .cabin:   return "10 кг"
        case .checked: return "23 кг"
        }
    }
}

/// Откуда вещь попала в чемодан.
enum PackSource: String, Hashable {
    /// Добавлена пользователем вручную.
    case manual
    /// Предложена алгоритмом автоматической сборки.
    case automatic
}

/// Вещь, уложенная в чемодан. Хранит копию вещи на момент упаковки,
/// чтобы правка гардероба не меняла задним числом собранный чемодан.
struct PackedItem: Identifiable, Hashable {
    let id: UUID
    var item: WardrobeItem
    var quantity: Int
    var isPacked: Bool
    var source: PackSource

    init(id: UUID = UUID(),
         item: WardrobeItem,
         quantity: Int = 1,
         isPacked: Bool = false,
         source: PackSource = .manual) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.isPacked = isPacked
        self.source = source
    }

    var totalWeightGrams: Int { item.weightGrams * quantity }
}

/// Поездка (чемодан) — набор упакованных вещей с ограничением по весу.
struct Trip: Identifiable, Hashable {
    let id: UUID
    var title: String
    var destination: String
    var kind: TripKind
    var startDate: Date
    var endDate: Date
    /// Лимит веса багажа в граммах.
    var limitGrams: Int
    var items: [PackedItem]

    init(id: UUID = UUID(),
         title: String,
         destination: String,
         kind: TripKind,
         startDate: Date,
         endDate: Date,
         limitGrams: Int = BaggageLimit.checked.grams,
         items: [PackedItem] = []) {
        self.id = id
        self.title = title
        self.destination = destination
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.limitGrams = limitGrams
        self.items = items
    }

    /// Количество ночей в поездке — основа для расчёта числа комплектов одежды.
    var nights: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days)
    }

    /// Суммарный вес всех уложенных вещей.
    var totalWeightGrams: Int {
        items.reduce(0) { $0 + $1.totalWeightGrams }
    }

    /// Доля заполнения чемодана относительно лимита. Может превышать единицу.
    var load: Double {
        guard limitGrams > 0 else { return 0 }
        return Double(totalWeightGrams) / Double(limitGrams)
    }

    /// Остаток свободного веса; при перевесе — отрицательный.
    var remainingGrams: Int { limitGrams - totalWeightGrams }

    var isOverLimit: Bool { totalWeightGrams > limitGrams }

    /// Сколько вещей уже физически сложено в чемодан.
    var packedCount: Int { items.filter(\.isPacked).count }

    var dateRangeTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}
