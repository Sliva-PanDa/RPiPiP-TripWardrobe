import SwiftUI

/// Экран сезона/стиля: список входящих в него образов.
struct SeasonView: View {
    @Environment(WardrobeStore.self) private var store
    let seasonID: SeasonStyle.ID

    var body: some View {
        if let season = store.season(id: seasonID) {
            List {
                Section {
                    LabeledContent("Образов", value: "\(season.looks.count)")
                    LabeledContent("Вещей", value: "\(season.itemCount)")
                    LabeledContent("Суммарный вес",
                                   value: WeightFormatter.string(grams: season.totalWeightGrams))
                }
                Section("Образы") {
                    ForEach(season.looks) { look in
                        NavigationLink(value: Route.look(look.id)) {
                            LookRow(look: look)
                        }
                    }
                }
            }
            .navigationTitle(season.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("seasonList")
        } else {
            ContentUnavailableView("Сезон не найден", systemImage: "square.stack.3d.up.slash")
        }
    }
}

/// Экран образа: перечень входящих вещей.
struct LookView: View {
    @Environment(WardrobeStore.self) private var store
    let lookID: Look.ID

    var body: some View {
        if let found = store.look(id: lookID) {
            List {
                Section {
                    LabeledContent("Сезон/стиль", value: found.season.name)
                    LabeledContent("Повод", value: found.look.occasion)
                    LabeledContent("Вещей", value: "\(found.look.items.count)")
                    LabeledContent("Суммарный вес",
                                   value: WeightFormatter.string(grams: found.look.totalWeightGrams))
                }
                Section("Вещи") {
                    ForEach(found.look.items) { item in
                        NavigationLink(value: Route.item(item.id)) {
                            ItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle(found.look.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("lookList")
        } else {
            ContentUnavailableView("Образ не найден", systemImage: "person.crop.rectangle.stack")
        }
    }
}

/// Экран вещи с указанием её местоположения в гардеробе.
struct ItemDetailView: View {
    @Environment(WardrobeStore.self) private var store
    let itemID: WardrobeItem.ID

    var body: some View {
        if let placement = store.placement(ofItem: itemID) {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: placement.item.icon)
                            .font(.system(size: 56))
                            .foregroundStyle(.blue)
                        Text(placement.item.name)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        StatusLabel(status: placement.item.status)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                Section("Сведения") {
                    LabeledContent("Категория", value: placement.item.category)
                    LabeledContent("Вес",
                                   value: WeightFormatter.string(grams: placement.item.weightGrams))
                    LabeledContent("Статус", value: placement.item.status.title)
                    if !placement.item.note.isEmpty {
                        LabeledContent("Заметка", value: placement.item.note)
                    }
                }
                Section("Местоположение") {
                    Label(placement.season.name, systemImage: placement.season.icon)
                    Label(placement.look.name, systemImage: "person.crop.rectangle.stack")
                }
            }
            .navigationTitle("Вещь")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("itemDetail")
        } else {
            ContentUnavailableView("Вещь не найдена", systemImage: "tshirt")
        }
    }
}
