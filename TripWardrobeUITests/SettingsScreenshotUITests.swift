import XCTest
import UIKit

/// UI-сценарии экрана настроек: значения из UserDefaults и смена темы.
/// Снимают скриншоты для отчёта по ЛР № 3.
final class SettingsScreenshotUITests: XCTestCase {

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

    /// На iPhone вкладки выводятся панелью снизу, на iPad в iPadOS 18 —
    /// сегментированным элементом сверху.
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

    // MARK: - Сценарии

    /// Экран настроек: тема оформления, лимит багажа и состояние базы данных.
    func test09Settings() {
        guard openTab("Настройки") else { return }
        _ = element("settingsForm").waitForExistence(timeout: 10)
        snapshot("13-settings")

        // Прокрутка до сведений о базе данных и синхронизации каталога.
        app.swipeUp()
        snapshot("14-settings-storage")
    }

    /// Смена темы оформления применяется ко всему приложению.
    func test10DarkAppearance() {
        guard openTab("Настройки") else { return }
        _ = element("settingsForm").waitForExistence(timeout: 10)

        let dark = app.buttons["Тёмная"].firstMatch
        if dark.waitForExistence(timeout: 10) {
            dark.tap()
            snapshot("15-appearance-dark")
        }

        if openTab("Гардероб") {
            snapshot("16-wardrobe-dark")
        }

        // Возврат к системной теме, чтобы не влиять на остальные сценарии.
        if openTab("Настройки") {
            let system = app.buttons["Системная"].firstMatch
            if system.waitForExistence(timeout: 10) { system.tap() }
        }
    }
}
