import SwiftUI

/// Экран настроек приложения.
/// Все значения этого экрана хранятся в UserDefaults и применяются сразу.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let repository: SwiftDataRepository
    let onResync: () async -> Void

    @State private var isResyncing = false

    var body: some View {
        Form {
            appearanceSection
            baggageSection
            storageSection
            serviceSection
        }
        .navigationTitle("Настройки")
        .accessibilityIdentifier("settingsForm")
    }

    // MARK: - Тема оформления

    private var appearanceSection: some View {
        Section {
            Picker("Тема оформления", selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.icon)
                        .tag(appearance)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityIdentifier("appearancePicker")
        } header: {
            Text("Оформление")
        } footer: {
            Text("Значение хранится в UserDefaults по ключу settings.appearance "
                 + "и применяется ко всему приложению модификатором preferredColorScheme.")
        }
    }

    // MARK: - Лимит веса багажа

    private var baggageSection: some View {
        Section {
            Picker("Лимит по умолчанию", selection: $settings.defaultLimitGrams) {
                ForEach(BaggageLimit.allCases) { limit in
                    Text(limit.title).tag(limit.grams)
                }
            }
            .accessibilityIdentifier("defaultLimitPicker")

            Stepper(value: $settings.defaultLimitGrams, in: 5_000...32_000, step: 1_000) {
                LabeledContent("Своё значение", value: settings.defaultLimitTitle)
            }
            .accessibilityIdentifier("limitStepper")
        } header: {
            Text("Багаж")
        } footer: {
            Text("Подставляется в каждую новую поездку.")
        }
    }

    // MARK: - Состояние хранилища

    private var storageSection: some View {
        Section {
            LabeledContent("Сезонов", value: "\(repository.seasons.count)")
            LabeledContent("Вещей", value: "\(repository.allPlacements.count)")
            LabeledContent("Поездок", value: "\(repository.trips.count)")
            if let report = repository.lastSyncReport {
                LabeledContent("Синхронизация каталога") {
                    Text(report.summary)
                        .multilineTextAlignment(.trailing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("База данных SwiftData")
        } footer: {
            Text("База наполняется каталогом при каждом запуске приложения. "
                 + "Поездки и вещи, добавленные вручную, при обновлении сохраняются.")
        }
    }

    // MARK: - Служебные действия

    private var serviceSection: some View {
        Section {
            Button {
                Task {
                    isResyncing = true
                    await onResync()
                    isResyncing = false
                }
            } label: {
                HStack {
                    Label("Обновить каталог", systemImage: "arrow.clockwise")
                    if isResyncing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isResyncing)
            .accessibilityIdentifier("resyncCatalog")

            LabeledContent("Первый запуск пройден",
                           value: settings.hasCompletedFirstLaunch ? "да" : "нет")

            Button("Сбросить настройки", role: .destructive) {
                settings.reset()
            }
            .accessibilityIdentifier("resetSettings")
        } header: {
            Text("Служебное")
        }
    }
}
