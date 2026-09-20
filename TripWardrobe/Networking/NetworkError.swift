import Foundation

/// Ошибки сетевого слоя.
///
/// Все ошибки URLSession и декодирования приводятся к этому типу,
/// чтобы модели представления работали с одним понятным перечислением,
/// а не с разнородными `Error`.
enum NetworkError: LocalizedError, Equatable {
    /// Нет соединения или сервер недоступен.
    case unreachable(String)
    /// Ответ сервера не является HTTP-ответом.
    case invalidResponse
    /// Код состояния 4xx — ошибка запроса.
    case clientError(Int)
    /// Код состояния 5xx — ошибка сервера.
    case serverError(Int)
    /// Тело ответа не соответствует ожидаемой структуре.
    case decoding(String)
    /// Запрошенный ресурс не найден в ответе сервиса.
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let reason):
            return "Нет связи с сервером: \(reason)"
        case .invalidResponse:
            return "Получен некорректный ответ сервера"
        case .clientError(let code):
            return "Ошибка запроса, код \(code)"
        case .serverError(let code):
            return "Сервер вернул ошибку, код \(code)"
        case .decoding(let reason):
            return "Не удалось разобрать ответ: \(reason)"
        case .notFound(let what):
            return "Не найдено: \(what)"
        }
    }

    /// Приведение произвольной ошибки к типу сетевого слоя.
    static func wrap(_ error: Error) -> NetworkError {
        if let network = error as? NetworkError {
            return network
        }
        if let decoding = error as? DecodingError {
            return .decoding(String(describing: decoding))
        }
        if let urlError = error as? URLError {
            return .unreachable(urlError.localizedDescription)
        }
        return .unreachable(error.localizedDescription)
    }
}

/// Проверка кода состояния HTTP-ответа.
enum HTTPValidator {
    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 400..<500:
            throw NetworkError.clientError(http.statusCode)
        default:
            throw NetworkError.serverError(http.statusCode)
        }
    }
}
