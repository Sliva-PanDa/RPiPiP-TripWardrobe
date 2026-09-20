import SwiftUI

/// Главный экран: иерархия «Сезон/Стиль → Образ → Вещь»,
/// текстовый поиск по вещам и фильтрация по статусу.
struct WardrobeHomeView: View {
    @Environment(WardrobeStore.self) private var store

    @State private var searchText = ""
    @State private var statusFilter: Set<ItemStatus> = []
    @State private var expanded: Set<Look.ID> = []

    var body: some View {
        List {
            summarySection
            filterSection

            if searchText.isEmpty {
                hierarchySection
            } else {
                searchSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Гардероб")
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Поиск вещи")
        .accessibilityIdentifier("homeList")
    }

    // MARK: - Сводка

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                StatBadge(value: "\(store.seasons.count)", title: "сезонов", icon: "square.stack.3d.up")
                StatBadge(value: "\(store.lookCount)", title: "образов", icon: "person.crop.rectangle.stack")
                StatBadge(value: "\(store.itemCount)", title: "вещей", icon: "tshirt")
                StatBadge(value: WeightFormatter.string(grams: store.totalWeightGrams),
                          title: "всего", icon: "scalemass")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    // MARK: - Фильтр по статусу

    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ItemStatus.allCases) { status in
                        StatusChip(status: status,
                                   count: store.count(of: status),
                                   isOn: statusFilter.contains(status)) {
                            toggle(status)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            HStack {
                Text("Статус вещи")
                Spacer()
                if !statusFilter.isEmpty {
                    Button("Сбросить") { statusFilter.removeAll() }
                        .font(.caption)
                        .textCase(nil)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("resetFilter")
                }
            }
        }
    }

    private func toggle(_ status: ItemStatus) {
        if statusFilter.contains(status) {
            statusFilter.remove(status)
        } else {
            statusFilter.insert(status)
        }
    }

    // MARK: - Иерархия

    @ViewBuilder
    private var hierarchySection: some View {
        let seasons = store.filteredSeasons(statuses: statusFilter)
        if seasons.isEmpty {
            Section {
                ContentUnavailableView("Нет вещей с выбранным статусом",
                                       systemImage: "line.3.horizontal.decrease.circle",
                                       description: Text("Снимите фильтр, чтобы увидеть весь гардероб."))
            }
        } else {
            ForEach(seasons) { season in
                Section {
                    NavigationLink(value: Route.season(season.id)) {
                        Label("Открыть сезон", systemImage: "arrow.right.circle")
                            .foregroundStyle(.tint)
                    }
                    .accessibilityIdentifier("openSeason_\(season.name)")

                    ForEach(season.looks) { look in
                        lookGroup(look)
                    }
                } header: {
                    SeasonHeader(season: season)
                }
            }
        }
    }

    private func lookGroup(_ look: Look) -> some View {
        DisclosureGroup(isExpanded: binding(for: look.id)) {
            ForEach(look.items) { item in
                NavigationLink(value: Route.item(item.id)) {
                    ItemRow(item: item)
                }
            }
            NavigationLink(value: Route.look(look.id)) {
                Label("Карточка образа", systemImage: "list.bullet.rectangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } label: {
            LookRow(look: look)
        }
        .accessibilityIdentifier("look_\(look.name)")
    }

    // MARK: - Результаты поиска

    @ViewBuilder
    private var searchSection: some View {
        let results = store.search(searchText, statuses: statusFilter)
        if results.isEmpty {
            Section {
                ContentUnavailableView.search(text: searchText)
            }
        } else {
            Section("Найдено: \(results.count)") {
                ForEach(results) { placement in
                    NavigationLink(value: Route.item(placement.item.id)) {
                        SearchResultRow(placement: placement, query: searchText)
                    }
                }
            }
        }
    }

    // MARK: - Вспомогательное

    private func binding(for id: Look.ID) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isOn in
                if isOn { expanded.insert(id) } else { expanded.remove(id) }
            }
        )
    }
}

#Preview {
    NavigationStack {
        WardrobeHomeView()
    }
    .environment(WardrobeStore())
}
