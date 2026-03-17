import SwiftUI
import SwiftData
import ActivityKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @Query private var sessions: [WorkoutSession]
    
    @State private var showingParser = false
    @State private var selectedLogForDescription: DailyLog?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    if logs.isEmpty {
                        ContentUnavailableView {
                            Label("Нет записей", systemImage: "calendar.badge.plus")
                                .foregroundStyle(.purple)
                        } description: {
                            Text("Ваши тренировки появятся здесь.")
                                .foregroundStyle(.gray)
                        }
                    } else {
                        List {
                            ForEach(logs) { log in
                                ZStack {
                                    NavigationLink {
                                        if let workout = log.workout {
                                            WorkoutExecutionView(session: workout)
                                        } else {
                                            Text("Запись от \(log.date.formatted())")
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
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .onOpenURL { url in
            if url.host == "complete-set" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    completeCurrentSetFromDeepLink()
                }
            }
        }
    }

    private func addLog() {
        withAnimation {
            let newLog = DailyLog(date: Date(), notes: "Новый тренировочный день")
            modelContext.insert(newLog)
        }
    }
    
    private func completeCurrentSetFromDeepLink() {
        guard let session = sessions.last(where: { session in
            session.exercises.contains { $0.sets.contains { !$0.isCompleted } }
        }) ?? sessions.last else { return }
        
        let sortedExercises = session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })
        guard let activeExercise = sortedExercises.first(where: { exercise in
            exercise.sets.contains { !$0.isCompleted }
        }) else { return }
        
        let sortedSets = activeExercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
        guard let currentSet = sortedSets.first(where: { !$0.isCompleted }) else { return }
        
        withAnimation {
            currentSet.isCompleted = true
            currentSet.completionTime = Date()
            if currentSet.actualWeight == nil || currentSet.actualWeight == 0 {
                currentSet.actualWeight = activeExercise.plannedWeight
            }
            if currentSet.actualReps == nil || currentSet.actualReps == 0 {
                currentSet.actualReps = currentSet.plannedReps
            }
            try? modelContext.save()
            updateLiveActivityAfterCompletion(session: session)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func updateLiveActivityAfterCompletion(session: WorkoutSession) {
        guard let activity = Activity<WorkoutAttributes>.activities.first else { return }
        let sortedExercises = session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })
        let activeExercise = sortedExercises.first(where: { exercise in
            exercise.sets.contains { !$0.isCompleted }
        }) ?? sortedExercises.last!
        
        let sortedSets = activeExercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
        let nextSet = sortedSets.first(where: { !$0.isCompleted }) ?? sortedSets.last!
        
        let weightVal = nextSet.actualWeight ?? activeExercise.plannedWeight
        let weightStr = weightVal == 0 ? "-" : (weightVal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", weightVal) : String(format: "%.1f", weightVal))
        let isAllDone = !session.exercises.contains { $0.sets.contains { !$0.isCompleted } }
        
        let updatedState = WorkoutAttributes.ContentState(
            exerciseName: activeExercise.name,
            currentSetNumber: nextSet.setNumber,
            totalSets: activeExercise.sets.count,
            weight: weightStr,
            reps: activeExercise.plannedRepsString ?? "\(nextSet.actualReps ?? nextSet.plannedReps)",
            isCompleted: isAllDone
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            if isAllDone {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                await activity.end(ActivityContent(state: updatedState, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }
}
