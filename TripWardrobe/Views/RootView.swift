import SwiftUI

/// Корневой экран приложения: два раздела — гардероб и поездки.
///
/// Модели представления создаются один раз и живут столько же, сколько экран,
/// поэтому состояние (строка поиска, фильтры) сохраняется при переключении вкладок.
struct RootView: View {
    private let services: ServiceContainer

    @State private var wardrobeViewModel: WardrobeListViewModel
    @State private var tripsViewModel: TripListViewModel

    init(services: ServiceContainer) {
        self.services = services
        _wardrobeViewModel = State(initialValue:
            WardrobeListViewModel(repository: services.repository))
        _tripsViewModel = State(initialValue:
            TripListViewModel(repository: services.repository))
    }

    var body: some View {
        TabView {
            wardrobeTab
                .tabItem { Label("Гардероб", systemImage: "tshirt") }

            tripsTab
                .tabItem { Label("Поездки", systemImage: "suitcase") }
        }
    }

    // MARK: - Вкладка «Гардероб»

    private var wardrobeTab: some View {
        NavigationStack {
            WardrobeHomeView(viewModel: wardrobeViewModel)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .season(let id):
            SeasonView(viewModel: wardrobeViewModel, seasonID: id)
        case .look(let id):
            LookView(viewModel: wardrobeViewModel, lookID: id)
        case .item(let id):
            ItemDetailView(viewModel: wardrobeViewModel, itemID: id)
        }
    }

    // MARK: - Вкладка «Поездки»

    private var tripsTab: some View {
        NavigationStack {
            TripListView(viewModel: tripsViewModel)
                .navigationDestination(for: TripRoute.self) { route in
                    switch route {
                    case .trip(let id):
                        if let trip = tripsViewModel.trip(id: id) {
                            TripDetailView(viewModel: TripDetailViewModel(
                                trip: trip,
                                repository: services.repository,
                                weatherService: services.weather,
                                packingService: services.packing))
                        } else {
                            ContentUnavailableView("Поездка не найдена",
                                                   systemImage: "suitcase")
                        }
                    }
                }
        }
    }
}

#Preview {
    RootView(services: ServiceContainer())
}
