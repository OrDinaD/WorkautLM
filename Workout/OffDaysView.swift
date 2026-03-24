import SwiftUI
import SwiftData

struct OffDaysView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @StateObject private var hkManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Сон сегодня")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(hkManager.sleepDurationToday, specifier: "%.1f") ч")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.purple)
                            }
                            Spacer()
                            Button("Обновить") {
                                hkManager.requestAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Данные о сне (HealthKit)").foregroundStyle(.gray)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section {
                        ForEach(logs.filter { $0.workout == nil }) { log in
                            VStack(alignment: .leading) {
                                Text(log.date, style: .date)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Сон: \(log.sleepDuration, specifier: "%.1f") ч")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                if !log.notes.isEmpty {
                                    Text(log.notes)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    } header: {
                        Text("Прошедшие дни отдыха").foregroundStyle(.gray)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Отдых")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
    }
}

#Preview {
    OffDaysView()
}
