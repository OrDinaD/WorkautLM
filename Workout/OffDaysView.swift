import SwiftUI
import SwiftData

struct OffDaysView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section {
                        ForEach(logs.filter { $0.workout == nil }) { log in
                            VStack(alignment: .leading) {
                                Text(log.date, style: .date)
                                    .font(.headline)
                                    .foregroundStyle(.white)
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
