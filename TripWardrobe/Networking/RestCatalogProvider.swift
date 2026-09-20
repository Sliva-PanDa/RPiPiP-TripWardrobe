import Combine
import Foundation
import Observation

/// Загрузка каталога гардероба по REST API.
///
/// Каталог отдаётся статическим mock-сервером (GitHub Pages) запросом
/// GET /api/catalog.json. Цепочка Combine проверяет код состояния ответа,
/// декодирует тело в структуру `CatalogDTO` и повторяет запрос при сбое сети.
final class RestCatalogProvider: CatalogProviding {

    private let session: URLSession
    private let url: URL

    init(session: URLSession = .shared, url: URL = API.catalog) {
        self.session = session
        self.url = url
    }

    /// Издатель каталога.
    func catalogPublisher() -> AnyPublisher<CatalogDTO, NetworkError> {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        return session.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .tryMap { data, response in
                try HTTPValidator.validate(response)
                return data
            }
            .decode(type: CatalogDTO.self, decoder: JSONDecoder.catalog)
            .mapError(NetworkError.wrap)
            // Одна повторная попытка на случай кратковременного сбоя сети.
            .retry(1)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Асинхронная обёртка над издателем для вызова из точки входа приложения.
    func loadCatalog() async throws -> CatalogDTO {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var resumed = false

            cancellable = catalogPublisher().sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion, !resumed {
                        resumed = true
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { catalog in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: catalog)
                }
            )
        }
    }
}

/// Каталог с резервным источником.
///
/// Если сервер недоступен, каталог берётся из ресурсов приложения — база
/// всё равно наполняется, и приложение остаётся работоспособным офлайн.
@Observable
final class FallbackCatalogProvider: CatalogProviding {

    /// Откуда фактически получен последний каталог.
    enum Source: String {
        case network = "REST API"
        case bundle = "ресурсы приложения"
    }

    @ObservationIgnored private let primary: any CatalogProviding
    @ObservationIgnored private let reserve: any CatalogProviding
    private(set) var lastSource: Source = .network
    private(set) var lastError: String?

    init(primary: any CatalogProviding = RestCatalogProvider(),
         reserve: any CatalogProviding = BundleCatalogProvider()) {
        self.primary = primary
        self.reserve = reserve
    }

    func loadCatalog() async throws -> CatalogDTO {
        do {
            let catalog = try await primary.loadCatalog()
            lastSource = .network
            lastError = nil
            return catalog
        } catch {
            lastSource = .bundle
            lastError = NetworkError.wrap(error).localizedDescription
            return try await reserve.loadCatalog()
        }
    }
}
