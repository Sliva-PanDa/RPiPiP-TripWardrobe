import XCTest
import UIKit

/// UI-сценарии, которые проходят по экранам приложения и снимают
/// скриншоты для отчёта. Запускаются на симуляторах iPhone и iPad в GitHub Actions.
final class ScreenshotUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Префикс имени вложения, по которому скриншоты разделяются по устройствам.
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

    /// Сохраняет текущий экран как вложение результата тестирования.
    private func snapshot(_ name: String) {
        // Пауза, чтобы анимации интерфейса успели завершиться.
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(devicePrefix)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Поиск элемента по идентификатору доступности независимо от его типа.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Ожидание готовности главного экрана.
    @discardableResult
    private func waitForHome() -> Bool {
        element("homeList").waitForExistence(timeout: 15)
            || app.staticTexts["Гардероб"].waitForExistence(timeout: 15)
    }

    // MARK: - Сценарии

    /// Главный экран: сводка, фильтр по статусу и иерархия «Сезон/Стиль → Образ → Вещь».
    func test01HomeHierarchy() {
        waitForHome()
        snapshot("01-home")

        let look = app.staticTexts["Пляжный день"].firstMatch
        if look.waitForExistence(timeout: 10) {
            look.tap()
            snapshot("02-look-expanded")
        }
    }

    /// Текстовый поиск по вещам и переход в карточку найденной вещи.
    func test02Search() {
        waitForHome()

        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout: 10) else { return }
        search.tap()
        search.typeText("руб")
        // Скрыть клавиатуру, чтобы на скриншоте был виден список результатов.
        search.typeText("\n")
        Thread.sleep(forTimeInterval: 1.5)
        snapshot("03-search")

        let firstResult = app.cells.firstMatch
        if firstResult.waitForExistence(timeout: 10) {
            firstResult.tap()
            _ = element("itemDetail").waitForExistence(timeout: 10)
            snapshot("04-item")
        }
    }

    /// Фильтрация гардероба по статусу вещи.
    func test03StatusFilter() {
        waitForHome()

        let laundry = element("filter_inLaundry")
        guard laundry.waitForExistence(timeout: 10) else { return }
        laundry.tap()
        snapshot("05-filter-laundry")
    }

    /// Навигация вглубь иерархии: экран сезона и экран образа.
    func test04Navigation() {
        waitForHome()

        let openSeason = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "openSeason_"))
            .firstMatch

        guard openSeason.waitForExistence(timeout: 10) else { return }
        if !openSeason.isHittable {
            app.swipeUp()
        }
        openSeason.tap()

        _ = element("seasonList").waitForExistence(timeout: 10)
        snapshot("06-season")

        // Первый образ сезона: ячейка в секции «Образы».
        let look = app.cells.element(boundBy: 3)
        if look.waitForExistence(timeout: 10) {
            look.tap()
            _ = element("lookList").waitForExistence(timeout: 10)
            snapshot("07-look")
        }
    }
}
