import SwiftUI

/// Список поездок (чемоданов).
struct TripListView: View {
    @Bindable var viewModel: TripListViewModel

    var body: some View {
        List {
            if viewModel.isEmpty {
                ContentUnavailableView("Поездок пока нет",
                                       systemImage: "suitcase",
                                       description: Text("Создайте поездку, чтобы собрать чемодан."))
            } else {
                ForEach(viewModel.trips) { trip in
                    NavigationLink(value: TripRoute.trip(trip.id)) {
                        TripRow(trip: trip)
                    }
                    .accessibilityIdentifier("trip_\(trip.title)")
                }
                .onDelete { viewModel.delete(atOffsets: $0) }
            }
        }
        .navigationTitle("Поездки")
        .accessibilityIdentifier("tripList")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Новая поездка", systemImage: "plus") {
                    viewModel.isNewTripPresented = true
                }
                .accessibilityIdentifier("newTrip")
            }
        }
        .sheet(isPresented: $viewModel.isNewTripPresented) {
            NewTripSheet { title, destination, kind, start, end, limit in
                viewModel.createTrip(title: title,
                                     destination: destination,
                                     kind: kind,
                                     startDate: start,
                                     endDate: end,
                                     limitGrams: limit)
            }
        }
    }
}

/// Строка поездки со сводкой по весу багажа.
struct TripRow: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: trip.kind.icon)
                    .foregroundStyle(.tint)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.title)
                        .font(.body.weight(.semibold))
                    Text("\(trip.destination) · \(trip.dateRangeTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(WeightFormatter.string(grams: trip.totalWeightGrams))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(trip.isOverLimit ? .red : .secondary)
            }

            BaggageProgressBar(load: trip.load, isOverLimit: trip.isOverLimit)
                .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

/// Полоса загрузки чемодана относительно лимита авиакомпании.
struct BaggageProgressBar: View {
    let load: Double
    let isOverLimit: Bool

    private var tint: Color {
        if isOverLimit { return .red }
        return load >= 0.85 ? .orange : .green
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(load, 0), 1))
            }
        }
        .accessibilityIdentifier("baggageProgress")
    }
}

/// Форма создания новой поездки.
struct NewTripSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String, String, TripKind, Date, Date, Int) -> Void

    @State private var title = ""
    @State private var destination = ""
    @State private var kind: TripKind = .beach
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 7)
    @State private var limit: BaggageLimit = .checked

    var body: some View {
        NavigationStack {
            Form {
                Section("Поездка") {
                    TextField("Название", text: $title)
                    TextField("Город назначения", text: $destination)
                    Picker("Тип поездки", selection: $kind) {
                        ForEach(TripKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.icon).tag(kind)
                        }
                    }
                }
                Section("Даты") {
                    DatePicker("Вылет", selection: $startDate, displayedComponents: .date)
                    DatePicker("Возвращение", selection: $endDate, displayedComponents: .date)
                }
                Section("Багаж") {
                    Picker("Лимит веса", selection: $limit) {
                        ForEach(BaggageLimit.allCases) { limit in
                            Text(limit.title).tag(limit)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Новая поездка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        onCreate(title, destination, kind, startDate, endDate, limit.grams)
                        dismiss()
                    }
                    .disabled(destination.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
