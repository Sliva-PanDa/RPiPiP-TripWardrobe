import XCTest
import UIKit

/// UI-сценарии лабораторной работы № 4: источник каталога по REST API,
/// поиск «на лету» и экспорт чек-листа чемодана.
final class ExportScreenshotUITests: XCTestCase {

    private var app: XCUIApplication!

    private var devicePrefix: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Вспомогательное

    private func snapshot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(devicePrefix)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func openTab(_ title: String) -> Bool {
        let candidates = [
            app.tabBars.buttons[title].firstMatch,
            app.segmentedControls.buttons[title].firstMatch,
            app.buttons[title].firstMatch
        ]
        for candidate in candidates where candidate.waitForExistence(timeout: 5) {
            candidate.tap()
            return true
        }
        return false
    }

    @discardableResult
    private func openFirstTrip() -> Bool {
        guard openTab("Поездки") else { return false }
        _ = element("tripList").waitForExistence(timeout: 10)
        let cell = app.cells.firstMatch
        guard cell.waitForExistence(timeout: 10) else { return false }
        cell.tap()
        return element("tripDetail").waitForExistence(timeout: 10)
    }

    // MARK: - Сценарии

    /// Раздел настроек с адресом mock-сервера и источником последней загрузки.
    func test11CatalogSource() {
        guard openTab("Настройки") else { return }
        _ = element("settingsForm").waitForExistence(timeout: 10)

        let source = element("catalogSource")
        if source.waitForExistence(timeout: 10), !source.isHittable {
            app.swipeUp()
        }
        snapshot("17-catalog-rest")
    }

    /// Поиск «на лету»: результаты пересчитываются после паузы в наборе.
    func test12LiveSearch() {
        guard openTab("Гардероб") else { return }
        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout: 10) else { return }

        search.tap()
        search.typeText("сла")
        search.typeText("\n")
        Thread.sleep(forTimeInterval: 1.5)
        snapshot("18-live-search")
    }

    /// Предварительный просмотр чек-листа чемодана.
    func test13ChecklistPreview() {
        guard openFirstTrip() else { return }

        let preview = element("previewChecklist")
        for _ in 0..<6 where !preview.isHittable {
            app.swipeUp()
        }
        guard preview.waitForExistence(timeout: 10) else { return }
        preview.tap()

        guard element("checklistPreview").waitForExistence(timeout: 10) else { return }
        snapshot("19-checklist")
    }

    /// Выгрузка чек-листа в файл через системное окно сохранения.
    func test14ExportFile() {
        guard openFirstTrip() else { return }

        let export = element("exportChecklist")
        for _ in 0..<6 where !export.isHittable {
            app.swipeUp()
        }
        guard export.waitForExistence(timeout: 10) else { return }
        export.tap()

        // Системное окно сохранения принадлежит другому процессу,
        // поэтому ждём его появления по снимку экрана.
        Thread.sleep(forTimeInterval: 3.0)
        snapshot("20-export-file")
    }
}
