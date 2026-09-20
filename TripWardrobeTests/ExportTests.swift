import XCTest
@testable import TripWardrobe

/// Тесты экспорта чек-листа и конвейера поиска «на лету».
final class ExportTests: XCTestCase {

    private func trip() -> Trip {
        let shirt = WardrobeItem(name: "Рубашка льняная", category: "Верх",
                                 icon: "tshirt", weightGrams: 240, status: .inTrip)
        let shoes = WardrobeItem(name: "Сланцы", category: "Обувь",
                                 icon: "figure.walk", weightGrams: 310)
        return Trip(title: "Отпуск на море",
                    destination: "Батуми",
                    kind: .beach,
                    startDate: Date(timeIntervalSince1970: 1_790_000_000),
                    endDate: Date(timeIntervalSince1970: 1_790_600_000),
                    limitGrams: BaggageLimit.cabin.grams,
                    items: [PackedItem(item: shirt, quantity: 2, isPacked: true),
                            PackedItem(item: shoes, quantity: 1)])
    }

    // MARK: - Чек-лист

    /// Чек-лист повторяет содержимое чемодана и суммарный вес.
    func testChecklistMirrorsTrip() {
        let source = trip()
        let checklist = PackingChecklist(trip: source)

        XCTAssertEqual(checklist.title, "Отпуск на море")
        XCTAssertEqual(checklist.destination, "Батуми")
        XCTAssertEqual(checklist.kind, "Пляж")
        XCTAssertEqual(checklist.entries.count, 2)
        XCTAssertEqual(checklist.totalWeightGrams, source.totalWeightGrams)
        XCTAssertEqual(checklist.entries.first?.weightGrams, 480)
        XCTAssertEqual(checklist.entries.first?.isPacked, true)
    }

    /// Файл кодируется в JSON и читается обратно без потерь.
    func testChecklistRoundTrip() throws {
        let checklist = PackingChecklist(trip: trip())
        let data = try checklist.encoded()

        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"total_weight_grams\""))
        XCTAssertTrue(text.contains("\"is_packed\""))

        let restored = try PackingChecklist.decoder.decode(PackingChecklist.self, from: data)
        XCTAssertEqual(restored, checklist)
    }

    /// Документ для системного окна сохранения хранит тот же чек-лист.
    func testChecklistDocumentKeepsChecklist() {
        let checklist = PackingChecklist(trip: trip())
        XCTAssertEqual(ChecklistDocument(checklist: checklist).checklist, checklist)
        XCTAssertEqual(ChecklistDocument.readableContentTypes.first?.identifier,
                       "public.json")
    }

    /// Текстовое представление отмечает уложенные вещи.
    func testChecklistPlainText() {
        let text = PackingChecklist(trip: trip()).plainText

        XCTAssertTrue(text.contains("Чек-лист чемодана: Отпуск на море"))
        XCTAssertTrue(text.contains("[x] Рубашка льняная × 2"))
        XCTAssertTrue(text.contains("[ ] Сланцы"))
    }

    /// Имя файла строится из названия поездки.
    func testChecklistFileName() {
        XCTAssertEqual(PackingChecklist(trip: trip()).fileName, "Чек-лист · Отпуск на море")
    }

    // MARK: - Поиск «на лету»

    /// Быстрый набор нескольких символов приводит к одной выборке:
    /// промежуточные значения отсекаются оператором debounce.
    func testDebouncedSearchCollapsesFastTyping() {
        let viewModel = WardrobeListViewModel(repository: WardrobeStore(),
                                              debounce: .milliseconds(150))
        waitUntil { viewModel.queryCount >= 1 }      // первое пустое значение
        let baseline = viewModel.queryCount

        for text in ["р", "ру", "руб", "руба"] {
            viewModel.searchText = text
        }
        waitUntil { viewModel.debouncedQuery == "руба" }

        XCTAssertEqual(viewModel.queryCount, baseline + 1)
        XCTAssertFalse(viewModel.isTypingAhead)
        XCTAssertTrue(viewModel.isSearching)
    }

    /// Повтор того же запроса не вызывает новую выборку.
    func testDuplicateQueryIsIgnored() {
        let viewModel = WardrobeListViewModel(repository: WardrobeStore(),
                                              debounce: .milliseconds(100))
        waitUntil { viewModel.queryCount >= 1 }

        viewModel.searchText = "пиджак"
        waitUntil { viewModel.debouncedQuery == "пиджак" }
        let afterFirst = viewModel.queryCount

        viewModel.searchText = "пиджак "
        viewModel.searchText = "пиджак"
        waitUntil(timeout: 1) { false }             // выдержать паузу

        XCTAssertEqual(viewModel.queryCount, afterFirst)
        XCTAssertFalse(viewModel.searchResults.isEmpty)
    }

    // MARK: - Вспомогательное

    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }
}
