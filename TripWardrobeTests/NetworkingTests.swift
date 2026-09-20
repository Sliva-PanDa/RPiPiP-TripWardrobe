import XCTest
import Combine
@testable import TripWardrobe

/// Перехватчик сетевых запросов: подменяет ответ сервера, поэтому тесты
/// сетевого слоя выполняются без доступа к интернету.
final class StubURLProtocol: URLProtocol {

    /// Обработчик, возвращающий код состояния и тело ответа для запроса.
    static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: status,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// Сессия, все запросы которой проходят через перехватчик.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// Тесты сетевого слоя: REST-запросы, конвейеры Combine и обработка ошибок.
final class NetworkingTests: XCTestCase {

    private var session: URLSession!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        session = StubURLProtocol.makeSession()
        cancellables = []
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        cancellables = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Вспомогательное

    /// Синхронное получение результата издателя.
    private func result<P: Publisher>(of publisher: P,
                                      timeout: TimeInterval = 30,
                                      file: StaticString = #filePath,
                                      line: UInt = #line)
        -> Result<P.Output, P.Failure>? {
        var outcome: Result<P.Output, P.Failure>?
        let expectation = expectation(description: "издатель завершился")

        publisher
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    outcome = .failure(error)
                }
                expectation.fulfill()
            }, receiveValue: { value in
                outcome = .success(value)
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: timeout)
        if outcome == nil {
            XCTFail("Издатель не завершился за \(timeout) с", file: file, line: line)
        }
        return outcome
    }

    private var catalogJSON: Data {
        Data("""
        {
          "version": 7,
          "updated_at": "2026-09-10T10:00:00Z",
          "seasons": [
            {
              "season_id": "s1", "title": "Лето", "icon": "sun.max",
              "looks": [
                {
                  "look_id": "l1", "title": "Пляж", "occasion": "Отдых",
                  "items": [
                    { "item_id": "i1", "title": "Плавки", "category": "Низ",
                      "icon": "drop", "weight_grams": 120 }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8)
    }

    // MARK: - Каталог по REST API

    /// Успешный ответ 200 разбирается в структуру каталога.
    func testCatalogIsLoadedFromRest() {
        StubURLProtocol.handler = { _ in (200, self.catalogJSON) }
        let provider = RestCatalogProvider(session: session)

        guard case .success(let catalog)? = result(of: provider.catalogPublisher()) else {
            return XCTFail("Каталог не загружен")
        }
        XCTAssertEqual(catalog.version, 7)
        XCTAssertEqual(catalog.seasons.count, 1)
        XCTAssertEqual(catalog.seasons[0].looks[0].items[0].name, "Плавки")
    }

    /// Код 404 превращается в ошибку запроса.
    func testClientErrorIsMapped() {
        StubURLProtocol.handler = { _ in (404, Data()) }
        let provider = RestCatalogProvider(session: session)

        guard case .failure(let error)? = result(of: provider.catalogPublisher()) else {
            return XCTFail("Ожидалась ошибка")
        }
        XCTAssertEqual(error, .clientError(404))
    }

    /// Код 503 превращается в ошибку сервера.
    func testServerErrorIsMapped() {
        StubURLProtocol.handler = { _ in (503, Data()) }
        let provider = RestCatalogProvider(session: session)

        guard case .failure(let error)? = result(of: provider.catalogPublisher()) else {
            return XCTFail("Ожидалась ошибка")
        }
        XCTAssertEqual(error, .serverError(503))
    }

    /// Некорректное тело ответа даёт ошибку разбора.
    func testDecodingErrorIsMapped() {
        StubURLProtocol.handler = { _ in (200, Data("не json".utf8)) }
        let provider = RestCatalogProvider(session: session)

        guard case .failure(let error)? = result(of: provider.catalogPublisher()) else {
            return XCTFail("Ожидалась ошибка")
        }
        if case .decoding = error { return }
        XCTFail("Ожидалась ошибка разбора, получено: \(error)")
    }

    /// Отсутствие сети даёт ошибку доступности.
    func testUnreachableIsMapped() {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let provider = RestCatalogProvider(session: session)

        guard case .failure(let error)? = result(of: provider.catalogPublisher()) else {
            return XCTFail("Ожидалась ошибка")
        }
        if case .unreachable = error { return }
        XCTFail("Ожидалась ошибка связи, получено: \(error)")
    }

    /// При недоступном сервере каталог берётся из ресурсов приложения.
    func testFallbackCatalogUsesBundle() async throws {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        let provider = FallbackCatalogProvider(
            primary: RestCatalogProvider(session: session),
            reserve: BundleCatalogProvider(bundle: .main))

        let catalog = try await provider.loadCatalog()

        XCTAssertEqual(provider.lastSource, .bundle)
        XCTAssertNotNil(provider.lastError)
        XCTAssertFalse(catalog.seasons.isEmpty)
    }

    // MARK: - Прогноз погоды

    /// Две последовательные выборки связываются оператором flatMap
    /// и сворачиваются в одну сводку погоды.
    func testWeatherChainCombinesGeocodingAndForecast() {
        StubURLProtocol.handler = { request in
            let url = request.url!.absoluteString
            if url.contains("geocoding") {
                return (200, Data("""
                {"results":[{"name":"Батуми","latitude":41.64,"longitude":41.64,"country":"Грузия"}]}
                """.utf8))
            }
            return (200, Data("""
            {"daily":{"time":["2026-10-03","2026-10-04"],
             "temperature_2m_max":[27.0,29.5],
             "temperature_2m_min":[19.0,21.0],
             "precipitation_probability_max":[10,45]}}
            """.utf8))
        }

        let service = OpenMeteoWeatherService(session: session)
        guard case .success(let snapshot)? = result(of: service.forecastPublisher(city: "Батуми"))
        else {
            return XCTFail("Прогноз не получен")
        }

        XCTAssertEqual(snapshot.city, "Батуми")
        XCTAssertEqual(snapshot.minTemperature, 19.0)
        XCTAssertEqual(snapshot.maxTemperature, 29.5)
        XCTAssertEqual(snapshot.precipitationProbability, 45)
        XCTAssertTrue(snapshot.isHot)
        XCTAssertTrue(snapshot.isRainy)
    }

    /// Неизвестный город даёт понятную ошибку, а не пустой прогноз.
    func testUnknownCityProducesNotFound() {
        StubURLProtocol.handler = { _ in (200, Data("{\"results\":[]}".utf8)) }
        let service = OpenMeteoWeatherService(session: session)

        guard case .failure(let error)? = result(of: service.forecastPublisher(city: "Нигде")) else {
            return XCTFail("Ожидалась ошибка")
        }
        if case .notFound = error { return }
        XCTFail("Ожидалось «не найдено», получено: \(error)")
    }
}
