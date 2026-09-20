import SwiftUI
import SwiftData

@main
struct TripWardrobeApp: App {

    /// Контейнер базы данных SwiftData: описывает схему и путь к файлу хранилища.
    private let modelContainer: ModelContainer

    /// Репозиторий поверх основного контекста базы данных.
    @State private var repository: SwiftDataRepository

    /// Контейнер зависимостей: сюда подставлен репозиторий SwiftData.
    @State private var services: ServiceContainer

    /// Настройки приложения из UserDefaults.
    @State private var settings = AppSettings()

    @State private var isBootstrapped = false

    init() {
        let schema = Schema([
            SeasonEntity.self,
            LookEntity.self,
            ItemEntity.self,
            TripEntity.self,
            PackedItemEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Если существующее хранилище несовместимо со схемой,
            // приложение поднимается на временной базе в памяти.
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }

        self.modelContainer = container
        let repository = SwiftDataRepository(context: container.mainContext)
        _repository = State(initialValue: repository)
        _services = State(initialValue: ServiceContainer(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services,
                     settings: settings,
                     repository: repository,
                     onResync: { await bootstrap(force: true) })
                .environment(services)
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .modelContainer(modelContainer)
                .task {
                    guard !isBootstrapped else { return }
                    isBootstrapped = true
                    await bootstrap(force: false)
                }
        }
    }

    /// Наполнение базы начальными данными при старте приложения.
    ///
    /// База изначально пуста. Каталог загружается при каждом запуске и
    /// сливается с уже существующими записями: пользовательские данные
    /// предыдущих сеансов — статусы вещей, созданные поездки — сохраняются.
    @MainActor
    private func bootstrap(force: Bool) async {
        do {
            let catalog = try await BundleCatalogProvider().loadCatalog()
            try repository.synchronize(with: catalog)
        } catch {
            print("Не удалось загрузить каталог: \(error.localizedDescription)")
        }

        // Демонстрационные поездки создаются только при самом первом запуске.
        if !settings.hasCompletedFirstLaunch && !force {
            repository.seedDemoTrips()
            settings.hasCompletedFirstLaunch = true
        }
    }
}
