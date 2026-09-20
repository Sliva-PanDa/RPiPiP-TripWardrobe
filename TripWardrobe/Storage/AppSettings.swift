import Foundation
import Observation
import SwiftUI

/// Глобальные настройки приложения, хранящиеся в UserDefaults.
///
/// UserDefaults — лёгкое хранилище списка свойств: сюда попадают только
/// небольшие скалярные значения (лимит веса багажа, выбранная тема
/// оформления и маркер первого запуска). Каталог гардероба и поездки
/// хранятся в базе данных SwiftData.
@Observable
final class AppSettings {

    /// Тема оформления приложения.
    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "Системная"
            case .light:  return "Светлая"
            case .dark:   return "Тёмная"
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light:  return "sun.max"
            case .dark:   return "moon"
            }
        }

        /// nil означает «следовать системной теме».
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    /// Ключи хранилища вынесены в одно место, чтобы исключить опечатки.
    private enum Key {
        static let defaultLimitGrams = "settings.defaultLimitGrams"
        static let appearance = "settings.appearance"
        static let hasCompletedFirstLaunch = "settings.hasCompletedFirstLaunch"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Лимит веса багажа по умолчанию — подставляется в новые поездки.
    var defaultLimitGrams: Int {
        didSet { defaults.set(defaultLimitGrams, forKey: Key.defaultLimitGrams) }
    }

    /// Тема оформления: системная, светлая или тёмная.
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// Маркер первого запуска: по нему создаются демонстрационные поездки.
    var hasCompletedFirstLaunch: Bool {
        didSet { defaults.set(hasCompletedFirstLaunch, forKey: Key.hasCompletedFirstLaunch) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedLimit = defaults.integer(forKey: Key.defaultLimitGrams)
        self.defaultLimitGrams = storedLimit > 0 ? storedLimit : BaggageLimit.checked.grams

        let storedAppearance = defaults.string(forKey: Key.appearance) ?? ""
        self.appearance = Appearance(rawValue: storedAppearance) ?? .system

        self.hasCompletedFirstLaunch = defaults.bool(forKey: Key.hasCompletedFirstLaunch)
    }

    var defaultLimitTitle: String { WeightFormatter.string(grams: defaultLimitGrams) }

    /// Возврат к значениям по умолчанию, включая маркер первого запуска.
    func reset() {
        for key in [Key.defaultLimitGrams, Key.appearance, Key.hasCompletedFirstLaunch] {
            defaults.removeObject(forKey: key)
        }
        defaultLimitGrams = BaggageLimit.checked.grams
        appearance = .system
        hasCompletedFirstLaunch = false
    }
}
