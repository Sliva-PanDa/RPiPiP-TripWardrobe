import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Чек-лист собранного чемодана — отчуждаемый файл данных для обмена
/// с попутчиками. Структура кодируется в JSON протоколом `Encodable`
/// и так же читается обратно протоколом `Decodable`.
struct PackingChecklist: Codable, Equatable {

    struct Entry: Codable, Equatable {
        let name: String
        let category: String
        let quantity: Int
        let weightGrams: Int
        let isPacked: Bool

        enum CodingKeys: String, CodingKey {
            case name = "title"
            case category
            case quantity
            case weightGrams = "weight_grams"
            case isPacked = "is_packed"
        }
    }

    let title: String
    let destination: String
    let kind: String
    let startDate: Date
    let endDate: Date
    let limitGrams: Int
    let totalWeightGrams: Int
    let entries: [Entry]
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case title
        case destination
        case kind = "trip_kind"
        case startDate = "start_date"
        case endDate = "end_date"
        case limitGrams = "limit_grams"
        case totalWeightGrams = "total_weight_grams"
        case entries = "items"
        case exportedAt = "exported_at"
    }

    init(trip: Trip, exportedAt: Date = .now) {
        self.title = trip.title
        self.destination = trip.destination
        self.kind = trip.kind.title
        self.startDate = trip.startDate
        self.endDate = trip.endDate
        self.limitGrams = trip.limitGrams
        self.totalWeightGrams = trip.totalWeightGrams
        self.entries = trip.items.map {
            Entry(name: $0.item.name,
                  category: $0.item.category,
                  quantity: $0.quantity,
                  weightGrams: $0.totalWeightGrams,
                  isPacked: $0.isPacked)
        }
        self.exportedAt = exportedAt
    }

    // MARK: - Сериализация

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    /// Текстовое представление чек-листа для предварительного просмотра.
    var plainText: String {
        var lines = [
            "Чек-лист чемодана: \(title)",
            "Направление: \(destination) · \(kind)",
            "Вес: \(WeightFormatter.string(grams: totalWeightGrams)) "
                + "из \(WeightFormatter.string(grams: limitGrams))",
            ""
        ]
        for entry in entries {
            let mark = entry.isPacked ? "[x]" : "[ ]"
            let quantity = entry.quantity > 1 ? " × \(entry.quantity)" : ""
            lines.append("\(mark) \(entry.name)\(quantity) — "
                         + WeightFormatter.string(grams: entry.weightGrams))
        }
        return lines.joined(separator: "\n")
    }

    /// Имя файла без расширения.
    var fileName: String {
        let safe = title.replacingOccurrences(of: "/", with: "-")
        return "Чек-лист · \(safe)"
    }
}

/// Документ для системного окна сохранения файла.
struct ChecklistDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var checklist: PackingChecklist

    init(checklist: PackingChecklist) {
        self.checklist = checklist
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        checklist = try PackingChecklist.decoder.decode(PackingChecklist.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try checklist.encoded())
    }
}
