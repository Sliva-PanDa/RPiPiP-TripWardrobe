import XCTest
import UIKit

/// Сценарий демонстрации приложения для записи видео.
///
/// В отличие от сценариев, снимающих скриншоты, здесь важен не результат,
/// а сам проход по экранам: между действиями выдерживаются паузы, чтобы
/// на записи было видно, что происходит.
final class DemoUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Пауза между действиями сценария.
    private let beat: TimeInterval = 1.6

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

    private func pause(_ multiplier: Double = 1) {
        Thread.sleep(forTimeInterval: beat * multiplier)
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
            pause()
            return true
        }
        return false
    }

    private func tapIfPossible(_ element: XCUIElement, scrolls: Int = 4) -> Bool {
        guard element.waitForExistence(timeout: 8) else { return false }
        var attempts = 0
        while !element.isHittable && attempts < scrolls {
            app.swipeUp()
            pause(0.4)
            attempts += 1
        }
        guard element.isHittable else { return false }
        element.tap()
        pause()
        return true
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists && back.isHittable {
            back.tap()
            pause(0.6)
        }
    }

    // MARK: - Сценарий

    /// Полный проход по функциям приложения: гардероб, поиск, фильтр,
    /// чемодан, автосборка, настройки и экспорт чек-листа.
    func testDemoWalkthrough() {
        // 1. Главный экран: иерархия «Сезон/Стиль → Образ → Вещь».
        _ = element("homeList").waitForExistence(timeout: 15)
        pause(2)

        let look = app.staticTexts["Пляжный день"].firstMatch
        if look.waitForExistence(timeout: 8) {
            look.tap()
            pause(2)
            look.tap()
            pause(0.6)
        }

        // 2. Поиск по вещам.
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 8) {
            search.tap()
            pause(0.5)
            search.typeText("руб")
            search.typeText("\n")
            pause(2)

            let first = app.cells.firstMatch
            if first.waitForExistence(timeout: 6) {
                first.tap()
                pause(2)
                goBack()
            }

            let cancel = app.buttons["Отменить"].firstMatch
            if cancel.exists { cancel.tap(); pause(0.6) }
        }

        // 3. Фильтр по статусу.
        _ = tapIfPossible(element("filter_inLaundry"))
        pause()
        _ = tapIfPossible(element("filter_inLaundry"))

        // 4. Карточка поездки: вес багажа и прогресс-бар лимита.
        if openTab("Поездки") {
            let trip = app.cells.firstMatch
            if trip.waitForExistence(timeout: 8) {
                trip.tap()
                _ = element("tripDetail").waitForExistence(timeout: 10)
                _ = element("weatherRow").waitForExistence(timeout: 12)
                pause(2.5)

                // 5. Автоматическая сборка чемодана.
                if tapIfPossible(element("autoPack")) {
                    if element("autoPackSheet").waitForExistence(timeout: 8) {
                        pause(2)
                        let applyAll = element("applyAll")
                        if applyAll.exists { applyAll.tap() }
                        _ = element("tripDetail").waitForExistence(timeout: 8)
                        pause(2)
                    }
                }

                // 6. Переключение лимита: перевес.
                let picker = element("limitPicker")
                if picker.waitForExistence(timeout: 8) {
                    let cabin = picker.buttons["10 кг"].firstMatch
                    if cabin.exists && cabin.isHittable { cabin.tap(); pause(2) }
                    let checked = picker.buttons["23 кг"].firstMatch
                    if checked.exists && checked.isHittable { checked.tap(); pause(1.5) }
                }

                // 7. Чек-лист чемодана.
                if tapIfPossible(element("previewChecklist")) {
                    if element("checklistPreview").waitForExistence(timeout: 8) {
                        pause(2.5)
                        let close = app.buttons["Закрыть"].firstMatch
                        if close.exists { close.tap(); pause(0.6) }
                    }
                }
                goBack()
            }
        }

        // 8. Настройки: тема оформления и источник каталога.
        if openTab("Настройки") {
            _ = element("settingsForm").waitForExistence(timeout: 8)
            pause(1.5)

            let dark = app.buttons["Тёмная"].firstMatch
            if dark.waitForExistence(timeout: 6) {
                dark.tap()
                pause(2)
            }

            app.swipeUp()
            pause(2)

            if openTab("Гардероб") {
                pause(2.5)
            }

            if openTab("Настройки") {
                let system = app.buttons["Системная"].firstMatch
                if system.waitForExistence(timeout: 6) { system.tap(); pause(1.5) }
            }
        }

        if openTab("Гардероб") {
            pause(2)
        }
    }
}
