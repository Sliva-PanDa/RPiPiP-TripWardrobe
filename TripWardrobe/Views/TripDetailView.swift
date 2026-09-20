import SwiftUI

/// Карточка поездки (чемодана): перечень упакованных вещей,
/// автоматический расчёт суммарного веса и полоса загрузки
/// относительно лимита авиакомпании.
struct TripDetailView: View {
    /// Модель представления принадлежит экрану и переживает перерисовки.
    @State private var viewModel: TripDetailViewModel

    init(viewModel: TripDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var bindable = viewModel

        return List {
            baggageSection
            weatherSection
            autoPackSection
            itemsSection
            if !viewModel.weightByCategory.isEmpty {
                breakdownSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tripDetail")
        .task { await viewModel.loadWeather() }
        .sheet(isPresented: $bindable.isAutoPackPresented) {
            AutoPackSheet(viewModel: viewModel)
        }
    }

    // MARK: - Вес багажа

    private var baggageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.totalWeightTitle)
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                        .foregroundStyle(viewModel.isOverLimit ? .red : .primary)
                    Text("из \(viewModel.limitTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.loadPercentTitle)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                BaggageProgressBar(load: viewModel.load,
                                   isOverLimit: viewModel.isOverLimit)
                    .frame(height: 10)

                HStack {
                    Label(viewModel.remainingTitle,
                          systemImage: viewModel.isOverLimit
                              ? "exclamationmark.triangle.fill"
                              : "checkmark.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(statusTint)
                    Spacer()
                    Text("Уложено \(viewModel.packedCountTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("Лимит", selection: limitBinding) {
                    ForEach(BaggageLimit.allCases) { limit in
                        Text(limit.shortTitle).tag(limit.grams)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("limitPicker")
            }
            .padding(.vertical, 6)
        } header: {
            Text("Вес багажа")
        }
    }

    private var statusTint: Color {
        if viewModel.isOverLimit { return .red }
        return viewModel.isNearLimit ? .orange : .green
    }

    private var limitBinding: Binding<Int> {
        Binding(get: { viewModel.trip.limitGrams },
                set: { viewModel.setLimit($0) })
    }

    // MARK: - Погода в точке назначения

    @ViewBuilder
    private var weatherSection: some View {
        Section("Погода · \(viewModel.trip.destination)") {
            switch viewModel.weatherState {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Запрашиваем прогноз…")
                        .foregroundStyle(.secondary)
                }
            case .loaded(let snapshot):
                HStack(spacing: 12) {
                    Image(systemName: snapshot.icon)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.summary)
                            .font(.subheadline.weight(.medium))
                        Text(weatherHint(snapshot))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("weatherRow")
            case .failed(let message):
                Label(message, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func weatherHint(_ snapshot: WeatherSnapshot) -> String {
        var hints: [String] = []
        if snapshot.isCold { hints.append("нужен тёплый слой") }
        if snapshot.isHot { hints.append("запас лёгкого верха") }
        if snapshot.isRainy { hints.append("вторая пара обуви") }
        return hints.isEmpty ? "Особых требований к вещам нет" : hints.joined(separator: ", ")
    }

    // MARK: - Автоматическая сборка

    private var autoPackSection: some View {
        Section {
            Button {
                viewModel.buildSuggestions()
            } label: {
                Label("Собрать чемодан автоматически", systemImage: "wand.and.stars")
            }
            .accessibilityIdentifier("autoPack")
        } footer: {
            Text("Базовый список формируется по типу поездки «\(viewModel.trip.kind.title)» "
                 + "и прогнозу погоды в точке назначения.")
        }
    }

    // MARK: - Содержимое чемодана

    private var itemsSection: some View {
        Section {
            if viewModel.trip.items.isEmpty {
                Text("Чемодан пуст")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.trip.items) { packed in
                    PackedItemRow(packed: packed) {
                        viewModel.togglePacked(packed)
                    }
                }
                .onDelete { viewModel.remove(atOffsets: $0) }
            }
        } header: {
            HStack {
                Text("Вещи в чемодане")
                Spacer()
                Text("\(viewModel.trip.items.count)")
            }
        }
    }

    // MARK: - Разбивка веса по категориям

    private var breakdownSection: some View {
        Section("Вес по категориям") {
            ForEach(viewModel.weightByCategory, id: \.category) { row in
                LabeledContent(row.category,
                               value: WeightFormatter.string(grams: row.grams))
            }
        }
    }
}

/// Строка вещи в чемодане с отметкой «уложено».
struct PackedItemRow: View {
    let packed: PackedItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: packed.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(packed.isPacked ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: packed.item.icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(packed.item.name)
                    .strikethrough(packed.isPacked, color: .secondary)
                HStack(spacing: 6) {
                    Text(packed.item.category)
                    if packed.source == .automatic {
                        Label("подобрано", systemImage: "wand.and.stars")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(WeightFormatter.string(grams: packed.totalWeightGrams))
                    .font(.subheadline.monospacedDigit())
                if packed.quantity > 1 {
                    Text("× \(packed.quantity)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Лист с автоматически подобранным списком вещей.
struct AutoPackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TripDetailViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.suggestions.isEmpty {
                    ContentUnavailableView("Добавить нечего",
                                           systemImage: "checkmark.circle",
                                           description: Text("Все подходящие вещи уже в чемодане."))
                } else {
                    Section {
                        ForEach(viewModel.suggestions) { suggestion in
                            SuggestionRow(suggestion: suggestion) {
                                viewModel.apply(suggestion)
                            }
                        }
                    } header: {
                        Text("Предложено: \(viewModel.suggestions.count) · "
                             + viewModel.suggestionsWeightTitle)
                    }
                }
            }
            .navigationTitle("Автосборка")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("autoPackSheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить всё") {
                        viewModel.applyAllSuggestions()
                        dismiss()
                    }
                    .disabled(viewModel.suggestions.isEmpty)
                    .accessibilityIdentifier("applyAll")
                }
            }
        }
    }
}

/// Строка рекомендации с обоснованием.
struct SuggestionRow: View {
    let suggestion: PackingSuggestion
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.item.icon)
                .foregroundStyle(.blue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.item.name)
                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(WeightFormatter.string(grams: suggestion.totalWeightGrams))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if suggestion.quantity > 1 {
                    Text("× \(suggestion.quantity)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }
}
