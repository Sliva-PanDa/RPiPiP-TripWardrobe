import SwiftUI

@main
struct TripWardrobeApp: App {
    /// Единый источник данных, создаваемый в точке входа и передаваемый
    /// вниз по иерархии экранов механизмом environment.
    @State private var store = WardrobeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
