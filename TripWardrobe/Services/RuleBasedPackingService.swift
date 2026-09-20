import Foundation

/// Правило базового набора: сколько вещей заданной категории нужно на поездку.
private struct PackingRule {
    let category: String
    /// Постоянная часть — сколько штук нужно независимо от длительности.
    let fixed: Int
    /// Переменная часть — одна вещь на указанное число ночей.
    let perNights: Int
    let maximum: Int

    /// Требуемое количество для поездки указанной длительности.
    func quantity(nights: Int) -> Int {
        guard perNights > 0 else { return min(fixed, maximum) }
        return min(fixed + Int(ceil(Double(nights) / Double(perNights))), maximum)
    }
}

/// Алгоритм автоматического формирования базового списка вещей.
///
/// Работает в два прохода: сначала по типу поездки строится набор правил
/// «категория — количество», затем набор корректируется прогнозом погоды
/// в точке назначения. Под каждое правило из гардероба подбираются
/// конкретные вещи: приоритет отдаётся тем, что лежат «В шкафу».
final class RuleBasedPackingService: PackingSuggesting {

    // MARK: - Базовые наборы по типу поездки

    private func baseRules(for kind: TripKind) -> [PackingRule] {
        switch kind {
        case .beach:
            return [
                PackingRule(category: "Верх", fixed: 1, perNights: 2, maximum: 5),
                PackingRule(category: "Низ", fixed: 1, perNights: 3, maximum: 4),
                PackingRule(category: "Обувь", fixed: 1, perNights: 0, maximum: 2),
                PackingRule(category: "Текстиль", fixed: 1, perNights: 0, maximum: 1),
                PackingRule(category: "Аксессуары", fixed: 1, perNights: 0, maximum: 2)
            ]
        case .business:
            return [
                PackingRule(category: "Верх", fixed: 2, perNights: 2, maximum: 5),
                PackingRule(category: "Низ", fixed: 1, perNights: 3, maximum: 3),
                PackingRule(category: "Обувь", fixed: 1, perNights: 0, maximum: 2),
                PackingRule(category: "Аксессуары", fixed: 1, perNights: 0, maximum: 2),
                PackingRule(category: "Бельё", fixed: 1, perNights: 2, maximum: 5)
            ]
        case .mountains:
            return [
                PackingRule(category: "Верх", fixed: 2, perNights: 3, maximum: 4),
                PackingRule(category: "Низ", fixed: 1, perNights: 4, maximum: 3),
                PackingRule(category: "Обувь", fixed: 1, perNights: 0, maximum: 2),
                PackingRule(category: "Бельё", fixed: 1, perNights: 2, maximum: 5),
                PackingRule(category: "Аксессуары", fixed: 1, perNights: 0, maximum: 2)
            ]
        }
    }

    // MARK: - Формирование рекомендаций

    func suggestions(for trip: Trip,
                     weather: WeatherSnapshot?,
                     wardrobe: [ItemPlacement]) -> [PackingSuggestion] {

        let nights = trip.nights
        var quantities: [String: Int] = [:]
        var reasons: [String: String] = [:]

        // Шаг 1. Базовый набор по типу поездки.
        for rule in baseRules(for: trip.kind) {
            quantities[rule.category] = rule.quantity(nights: nights)
            reasons[rule.category] = "Тип поездки «\(trip.kind.title)», \(nights) ноч."
        }

        // Шаг 2. Поправки по прогнозу погоды в точке назначения.
        if let weather {
            if weather.isCold {
                quantities["Верх", default: 0] += 1
                quantities["Бельё", default: 0] += 1
                reasons["Верх"] = "Холодно (до \(Int(weather.minTemperature)) °C): нужен тёплый слой"
                reasons["Бельё"] = "Холодно: дополнительное термобельё"
            }
            if weather.isHot {
                quantities["Верх", default: 0] += 1
                reasons["Верх"] = "Жарко (до \(Int(weather.maxTemperature)) °C): запас лёгкого верха"
            }
            if weather.isRainy {
                quantities["Обувь", default: 0] += 1
                reasons["Обувь"] = "Осадки \(weather.precipitationProbability) %: вторая пара обуви"
            }
        }

        // Шаг 3. Подбор конкретных вещей гардероба под каждую категорию.
        let alreadyPacked = Set(trip.items.map(\.item.id))

        return quantities
            .sorted { $0.key < $1.key }
            .flatMap { category, needed -> [PackingSuggestion] in
                let candidates = wardrobe
                    .filter { $0.item.category == category }
                    .filter { !alreadyPacked.contains($0.item.id) }
                    // Вещи «В шкафу» доступны сразу, «В стирке» — в последнюю очередь.
                    .sorted { lhs, rhs in
                        let order: (ItemStatus) -> Int = { status in
                            switch status {
                            case .inCloset:  return 0
                            case .inTrip:    return 1
                            case .inLaundry: return 2
                            }
                        }
                        if order(lhs.item.status) != order(rhs.item.status) {
                            return order(lhs.item.status) < order(rhs.item.status)
                        }
                        // При равном статусе легче — значит лучше для веса багажа.
                        return lhs.item.weightGrams < rhs.item.weightGrams
                    }

                guard !candidates.isEmpty else { return [] }

                let reason = reasons[category] ?? "Базовый набор"
                // Если подходящих вещей меньше, чем требуется, недостающие
                // количества распределяются на уже найденные вещи.
                let distinct = min(candidates.count, needed)
                var result: [PackingSuggestion] = []
                for index in 0..<distinct {
                    let extra = (needed - distinct) > index ? 1 : 0
                    result.append(PackingSuggestion(item: candidates[index].item,
                                                    quantity: 1 + extra,
                                                    reason: reason))
                }
                return result
            }
    }
}
