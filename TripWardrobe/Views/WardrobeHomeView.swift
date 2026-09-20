import SwiftUI

/// Главный экран: иерархия «Сезон/Стиль → Образ → Вещь»,
/// текстовый поиск по вещам и фильтрация по статусу.
///
/// Представление не содержит логики: всё состояние и все вычисления
/// вынесены в `WardrobeListViewModel`.
struct WardrobeHomeView: View {
    @Bindable var viewModel: WardrobeListViewModel

    var body: some View {
        List {
            summarySection
            filterSection

            if viewModel.isSearching {
                searchSection
            } else {
                hierarchySection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Гардероб")
        .searchable(text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Поиск вещи")
        .accessibilityIdentifier("homeList")
    }

    // MARK: - Сводка

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                StatBadge(value: "\(viewModel.seasonCount)", title: "сезонов",
                          icon: "square.stack.3d.up")
                StatBadge(value: "\(viewModel.lookCount)", title: "образов",
                          icon: "person.crop.rectangle.stack")
                StatBadge(value: "\(viewModel.itemCount)", title: "вещей",
                          icon: "tshirt")
                StatBadge(value: viewModel.totalWeightTitle, title: "всего",
                          icon: "scalemass")
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
                                   count: viewModel.count(of: status),
                                   isOn: viewModel.statusFilter.contains(status)) {
                            viewModel.toggle(status)
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
                if !viewModel.statusFilter.isEmpty {
                    Button("Сбросить") { viewModel.resetFilter() }
                        .font(.caption)
                        .textCase(nil)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("resetFilter")
                }
            }
        }
    }

    // MARK: - Иерархия

    @ViewBuilder
    private var hierarchySection: some View {
        let seasons = viewModel.seasons
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
        DisclosureGroup(isExpanded: expansionBinding(for: look.id)) {
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
        let results = viewModel.searchResults
        if results.isEmpty {
            Section {
                ContentUnavailableView.search(text: viewModel.debouncedQuery)
            }
        } else {
            Section {
                ForEach(results) { placement in
                    NavigationLink(value: Route.item(placement.item.id)) {
                        SearchResultRow(placement: placement, query: viewModel.debouncedQuery)
                    }
                }
            } header: {
                HStack {
                    Text("Найдено: \(results.count)")
                    if viewModel.isTypingAhead {
                        Spacer()
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        }
    }

    // MARK: - Вспомогательное

    private func expansionBinding(for id: Look.ID) -> Binding<Bool> {
        Binding(
            get: { viewModel.isExpanded(id) },
            set: { viewModel.setExpanded($0, for: id) }
        )
    }
}

#Preview {
    let services = ServiceContainer()
    return NavigationStack {
        WardrobeHomeView(viewModel: WardrobeListViewModel(repository: services.repository))
    }
}
