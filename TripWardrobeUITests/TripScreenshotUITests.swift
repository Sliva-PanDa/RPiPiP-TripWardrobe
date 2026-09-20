import XCTest
import UIKit

/// UI-сценарии раздела «Поездки»: карточка чемодана, расчёт веса багажа
/// и автоматическая сборка. Снимают скриншоты для отчёта по ЛР № 2.
final class TripScreenshotUITests: XCTestCase {

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
        openTripsTab()
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

    /// Переключение раздела. На iPhone вкладки выводятся панелью снизу,
    /// на iPad в iPadOS 18 — сегментированным элементом сверху, поэтому
    /// элемент ищется в обоих представлениях.
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

    private func openTripsTab() {
        openTab("Поездки")
        _ = element("tripList").waitForExistence(timeout: 10)
    }

    /// Открывает карточку первой поездки в списке.
    @discardableResult
    private func openFirstTrip() -> Bool {
        let cell = app.cells.firstMatch
        guard cell.waitForExistence(timeout: 10) else { return false }
        cell.tap()
        return element("tripDetail").waitForExistence(timeout: 10)
    }

    // MARK: - Сценарии

    /// Список поездок с полосами загрузки чемоданов.
    func test05TripList() {
        snapshot("08-trip-list")
    }

    /// Карточка поездки: суммарный вес, прогресс-бар лимита и прогноз погоды.
    func test06TripDetail() {
        guard openFirstTrip() else { return }
        // Дождаться загрузки прогноза погоды.
        _ = element("weatherRow").waitForExistence(timeout: 10)
        snapshot("09-trip-detail")
    }

    /// Автоматическая сборка: предложенный список с обоснованиями.
    func test07AutoPack() {
        guard openFirstTrip() else { return }
        _ = element("weatherRow").waitForExistence(timeout: 10)

        let autoPack = element("autoPack")
        guard autoPack.waitForExistence(timeout: 10) else { return }
        if !autoPack.isHittable { app.swipeUp() }
        autoPack.tap()

        guard element("autoPackSheet").waitForExistence(timeout: 10) else { return }
        snapshot("10-autopack")

        let applyAll = element("applyAll")
        if applyAll.waitForExistence(timeout: 5) {
            applyAll.tap()
            _ = element("tripDetail").waitForExistence(timeout: 10)
            snapshot("11-trip-packed")
        }
    }

    /// Перевес: после смены лимита на ручную кладь полоса становится красной.
    func test08Overweight() {
        guard openFirstTrip() else { return }
        _ = element("weatherRow").waitForExistence(timeout: 10)

        let autoPack = element("autoPack")
        if autoPack.waitForExistence(timeout: 10) {
            if !autoPack.isHittable { app.swipeUp() }
            autoPack.tap()
            if element("autoPackSheet").waitForExistence(timeout: 10) {
                element("applyAll").tap()
                _ = element("tripDetail").waitForExistence(timeout: 10)
            }
        }

        // Переключение сегмента лимита на «10 кг».
        let picker = element("limitPicker")
        if picker.waitForExistence(timeout: 10) {
            let cabin = picker.buttons["10 кг"].firstMatch
            if cabin.exists { cabin.tap() }
            snapshot("12-limit-switch")
        }
    }
}
