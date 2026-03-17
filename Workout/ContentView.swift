import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    @State private var showingParser = false
    @State private var selectedLogForDescription: DailyLog?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    if logs.isEmpty {
                        ContentUnavailableView {
                            Label("No Logs", systemImage: "calendar.badge.plus")
                                .foregroundStyle(.purple)
                        } description: {
                            Text("Your workout and nutrition logs will appear here.")
                                .foregroundStyle(.gray)
                        }
                    } else {
                        List {
                            ForEach(logs) { log in
                                ZStack {
                                    // Hidden NavigationLink to remove the default grey arrow
                                    NavigationLink {
                                        if let workout = log.workout {
                                            WorkoutExecutionView(session: workout)
                                        } else {
                                            Text("Log for \(log.date.formatted())")
                                                .foregroundStyle(.white)
                                        }
                                    } label: {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(log.date, style: .date)
                                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            if !log.notes.isEmpty {
                                                Text(log.notes)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.gray)
                                                    .lineLimit(2)
                                                    .truncationMode(.tail)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.purple)
                                    }
                                }
                                .listRowBackground(Color.black)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            modelContext.delete(log)
                                        }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        selectedLogForDescription = log
                                    } label: {
                                        Label("Описание", systemImage: "doc.text")
                                    }
                                    .tint(.purple)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.black)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Тренировки")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingParser = true }) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.purple)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addLog) {
                        Image(systemName: "plus")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingParser) {
                SmartPlanParserView()
            }
            .sheet(item: $selectedLogForDescription) { log in
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ScrollView {
                            Text(log.notes)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .navigationTitle("Описание")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Закрыть") {
                                selectedLogForDescription = nil
                            }
                            .foregroundStyle(.purple)
                        }
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(.purple)
    }

    private func addLog() {
        withAnimation {
            let newLog = DailyLog(date: Date(), notes: "New training day")
            modelContext.insert(newLog)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, configurations: config)
    return ContentView()
        .modelContainer(container)
}
