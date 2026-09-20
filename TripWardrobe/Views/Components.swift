import SwiftUI

extension ItemStatus {
    /// Цветовая метка статуса. Вынесена в слой представления,
    /// чтобы модель не зависела от SwiftUI.
    var tint: Color {
        switch self {
        case .inCloset:  return .green
        case .inTrip:    return .orange
        case .inLaundry: return .blue
        }
    }
}

/// Заголовок секции сезона/стиля.
struct SeasonHeader: View {
    let season: SeasonStyle

    var body: some View {
        HStack {
            Image(systemName: season.icon)
            Text(season.name)
            Spacer()
            Text("\(season.looks.count) обр. · \(season.itemCount) вещ.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.headline)
        .textCase(nil)
    }
}

/// Строка образа в иерархии.
struct LookRow: View {
    let look: Look

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle.stack")
                .foregroundStyle(.purple)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(look.name)
                    .font(.body.weight(.semibold))
                Text(look.occasion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(WeightFormatter.string(grams: look.totalWeightGrams))
                .font(.caption.weight(.bold).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.purple.opacity(0.15), in: Capsule())
        }
    }
}

/// Строка вещи.
struct ItemRow: View {
    let item: WardrobeItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                HStack(spacing: 6) {
                    Text(item.category)
                    Text("·")
                    StatusLabel(status: item.status)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(WeightFormatter.string(grams: item.weightGrams))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// Результат поиска с указанием местоположения вещи.
struct SearchResultRow: View {
    let placement: ItemPlacement
    let query: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: placement.item.icon)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(highlighted(placement.item.name))
                Label(placement.path, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusLabel(status: placement.item.status)
                    .font(.caption2)
            }
            Spacer()
            Text(WeightFormatter.string(grams: placement.item.weightGrams))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// Подсветка совпавшей части названия.
    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        if let range = result.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            result[range].font = .body.bold()
            result[range].foregroundColor = .accentColor
        }
        return result
    }
}

/// Подпись статуса вещи с цветовой меткой.
struct StatusLabel: View {
    let status: ItemStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
            Text(status.title)
        }
        .foregroundStyle(status.tint)
    }
}

/// Кнопка-фильтр по статусу.
struct StatusChip: View {
    let status: ItemStatus
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                Text(status.title)
                    .fixedSize()
                Text("\(count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.background.opacity(0.6), in: Capsule())
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isOn ? status.tint.opacity(0.25) : Color.gray.opacity(0.12),
                        in: Capsule())
            .overlay(
                Capsule().strokeBorder(isOn ? status.tint : .clear, lineWidth: 1.5)
            )
            .foregroundStyle(isOn ? status.tint : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filter_\(status.rawValue)")
    }
}

/// Плитка со сводным показателем.
struct StatBadge: View {
    let value: String
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
