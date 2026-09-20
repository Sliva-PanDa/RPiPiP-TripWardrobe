import Foundation

/// Каталог начальных данных гардероба.
///
/// В лабораторной работе № 3 структура читается из файла ресурсов приложения
/// через протокол `Decodable`, в лабораторной работе № 4 — из ответа REST API.
/// Имена ключей в JSON заданы в стиле snake_case и не совпадают с именами
/// свойств, поэтому сопоставление выполняется перечислением `CodingKeys`.
struct CatalogDTO: Decodable {
    let version: Int
    let updatedAt: Date?
    let seasons: [SeasonDTO]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case seasons
    }
}

struct SeasonDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let looks: [LookDTO]

    enum CodingKeys: String, CodingKey {
        case id = "season_id"
        case name = "title"
        case icon
        case looks
    }
}

struct LookDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let occasion: String
    let items: [ItemDTO]

    enum CodingKeys: String, CodingKey {
        case id = "look_id"
        case name = "title"
        case occasion
        case items
    }
}

struct ItemDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let icon: String
    let weightGrams: Int
    let note: String?
    /// Начальный статус вещи. Применяется только при первом добавлении записи:
    /// статус, выставленный пользователем, при обновлении каталога сохраняется.
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id = "item_id"
        case name = "title"
        case category
        case icon
        case weightGrams = "weight_grams"
        case note
        case status
    }

    var initialStatus: ItemStatus {
        ItemStatus(rawValue: status ?? "") ?? .inCloset
    }
}

extension JSONDecoder {
    /// Декодер каталога: даты приходят в формате ISO 8601.
    static var catalog: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
