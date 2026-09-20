import SwiftUI

/// Корневой экран: стек навигации «Сезон/Стиль → Образ → Вещь».
struct RootView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WardrobeHomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .season(let id):
                        SeasonView(seasonID: id)
                    case .look(let id):
                        LookView(lookID: id)
                    case .item(let id):
                        ItemDetailView(itemID: id)
                    }
                }
        }
    }
}

#Preview {
    RootView()
        .environment(WardrobeStore())
}
