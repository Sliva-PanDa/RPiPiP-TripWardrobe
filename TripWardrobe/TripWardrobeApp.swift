import SwiftUI

@main
struct TripWardrobeApp: App {
    /// Контейнер зависимостей собирается один раз в точке входа
    /// и передаётся вниз по иерархии экранов через environment.
    @State private var services = ServiceContainer()

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .environment(services)
        }
    }
}
