import Foundation
import Observation

/// Модель представления списка поездок.
@Observable
final class TripListViewModel {

    private let repository: any TripStoring
    /// Настройки из UserDefaults: отсюда берётся лимит веса для новой поездки.
    private let settings: AppSettings

    var isNewTripPresented = false

    init(repository: any TripStoring, settings: AppSettings) {
        self.repository = repository
        self.settings = settings
    }

    var trips: [Trip] {
        repository.trips.sorted { $0.startDate < $1.startDate }
    }

    var isEmpty: Bool { repository.trips.isEmpty }

    /// Лимит веса по умолчанию для формы создания поездки.
    var defaultLimitGrams: Int { settings.defaultLimitGrams }

    func trip(id: Trip.ID) -> Trip? { repository.trip(id: id) }

    func delete(atOffsets offsets: IndexSet) {
        let sorted = trips
        for index in offsets where sorted.indices.contains(index) {
            repository.delete(tripID: sorted[index].id)
        }
    }

    /// Создаёт поездку и сохраняет её в хранилище.
    @discardableResult
    func createTrip(title: String,
                    destination: String,
                    kind: TripKind,
                    startDate: Date,
                    endDate: Date,
                    limitGrams: Int) -> Trip {
        let trip = Trip(title: title.isEmpty ? "Новая поездка" : title,
                        destination: destination,
                        kind: kind,
                        startDate: startDate,
                        endDate: endDate,
                        limitGrams: limitGrams)
        repository.save(trip)
        return trip
    }
}
