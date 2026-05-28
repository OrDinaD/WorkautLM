import SwiftUI
import SwiftData

struct SmartPlanParserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var logs: [DailyLog]
    
    @State private var rawText: String = ""
    @State private var parsedWorkout: ParsedWorkout? = nil
    @State private var revealedExerciseIndices: Set<Int> = []
    
    private var todayLog: DailyLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    @State private var recommendationsExpanded: Bool = false

    init(rawText: String = "", parsedWorkout: ParsedWorkout? = nil) {
        _rawText = State(initialValue: rawText)
        _parsedWorkout = State(initialValue: parsedWorkout)
        _revealedExerciseIndices = State(initialValue: Set(0..<(parsedWorkout?.exercises.count ?? 0)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if parsedWorkout == nil {
                        VStack(spacing: 16) {
                            Text("Вставьте ваш план тренировки ниже.")
                                .foregroundStyle(.gray)
                                .font(.subheadline)
                                .padding(.top)
                            
                            TextEditor(text: $rawText)
                                .scrollContentBackground(.hidden)
                                .background(Color(.systemGray6).opacity(0.1))
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal)
                                .scrollDismissesKeyboard(.interactively)
                            
                            Button(action: parseText) {
                                Text("Разобрать план")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                            .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(rawText.isEmpty ? 0.5 : 1.0)
                        }
                    } else {
                        parsedResultView
                    }
                }
            }
            .navigationTitle("Умный парсер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(.purple)
                }
                
                if parsedWorkout != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Сброс") {
                            withAnimation {
                                parsedWorkout = nil
                                revealedExerciseIndices = []
                                recommendationsExpanded = false
                            }
                        }
                        .foregroundStyle(.purple)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    private var parsedResultView: some View {
        VStack(spacing: 0) {
            List {
                if let notes = parsedWorkout?.recommendations, !notes.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .lineLimit(recommendationsExpanded ? nil : 3)
                            
                            Button(recommendationsExpanded ? "Свернуть" : "Развернуть...") {
                                withAnimation {
                                    recommendationsExpanded.toggle()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.purple)
                        }
                        .listRowBackground(Color.black)
                    } header: {
                        Text("Рекомендации").foregroundStyle(.purple)
                    }
                }
                
                if parsedWorkout != nil {
                    Section {
                        ForEach(Array((parsedWorkout?.exercises ?? []).enumerated()), id: \.offset) { index, exercise in
                            exerciseEditRow(index: index)
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                                .opacity(revealedExerciseIndices.contains(index) ? 1 : 0)
                                .offset(y: revealedExerciseIndices.contains(index) ? 0 : 38)
                                .scaleEffect(revealedExerciseIndices.contains(index) ? 1 : 0.96, anchor: .bottom)
                        }
                        .onDelete(perform: deleteExercises)
                        
                        Button(action: addExercise) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Добавить упражнение")
                            }
                            .foregroundStyle(.purple)
                        }
                        .listRowBackground(Color.black)
                    } header: {
                        Text("Тренировка").foregroundStyle(.purple)
                    }
                }
            }
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: parsedWorkout?.exercises.count ?? 0)
            
            Button(action: savePlan) {
                Text("Сохранить в лог")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding()
            .background(Color.black)
        }
    }
    
    @ViewBuilder
    private func exerciseEditRow(index: Int) -> some View {
        if let exercise = parsedWorkout?.exercises[index] {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Название упражнения", text: Binding(
                    get: { exercise.name },
                    set: { parsedWorkout?.exercises[index].name = $0 }
                ))
                .font(.headline)
                .foregroundStyle(.white)
                
                HStack(alignment: .center, spacing: 15) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Подходы x Повт")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        
                        // Sets x Reps editing
                        HStack(spacing: 4) {
                            TextField("Сеты", value: Binding(
                                get: { exercise.sets.count },
                                set: { newValue in
                                    let count = max(1, newValue)
                                    let reps = exercise.sets.first?.plannedReps ?? 10
                                    parsedWorkout?.exercises[index].sets = (1...count).map { WorkoutSet(setNumber: $0, plannedReps: reps) }
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 35)
                            .multilineTextAlignment(.center)
                            .padding(4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                            
                            Text("x")
                                .foregroundStyle(.gray)
                            
                            TextField("Повт", value: Binding(
                                get: { exercise.sets.first?.plannedReps ?? 10 },
                                set: { newValue in
                                    let reps = max(1, newValue)
                                    for i in 0..<(parsedWorkout?.exercises[index].sets.count ?? 0) {
                                        parsedWorkout?.exercises[index].sets[i].plannedReps = reps
                                    }
                                }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 45)
                            .multilineTextAlignment(.center)
                            .padding(4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Вес (кг)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        
                        TextField("0.0", value: Binding(
                            get: { exercise.plannedWeight },
                            set: { parsedWorkout?.exercises[index].plannedWeight = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .padding(4)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundStyle(.purple)
                        .bold()
                    }
                }
                
                if let recs = exercise.recommendations, !recs.isEmpty {
                    Text(recs)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.8))
                        .italic()
                }
            }
            .padding(.vertical, 8)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.55),
                                Color.purple.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.purple.opacity(0.16), radius: 16, x: 0, y: 10)
            .padding(.vertical, 4)
        }
    }
    
    private func parseText() {
        let parsed = PlanParser.parse(rawText)
        revealedExerciseIndices = []
        
        withAnimation(.easeOut(duration: 0.2)) {
            parsedWorkout = parsed
        }
        
        revealParsedExercises(count: parsed.exercises.count)
    }
    
    private func deleteExercises(at offsets: IndexSet) {
        parsedWorkout?.exercises.remove(atOffsets: offsets)
        revealedExerciseIndices = Set(0..<(parsedWorkout?.exercises.count ?? 0))
        // No need to re-index here, savePlan will handle it
    }
    
    private func addExercise() {
        let newExercise = Exercise(
            name: "",
            orderIndex: (parsedWorkout?.exercises.count ?? 0) + 1,
            sets: [WorkoutSet(setNumber: 1, plannedReps: 10)],
            plannedWeight: 0,
            plannedWeightString: nil,
            plannedRepsString: nil,
            notes: "",
            recommendations: "",
            isWarmup: false
        )
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            parsedWorkout?.exercises.append(newExercise)
            if let lastIndex = parsedWorkout?.exercises.indices.last {
                revealedExerciseIndices.insert(lastIndex)
            }
        }
    }
    
    private func savePlan() {
        guard let parsed = parsedWorkout else { return }
        
        let log: DailyLog
        if let existing = todayLog {
            log = existing
        } else {
            log = DailyLog(date: Date(), notes: "")
            modelContext.insert(log)
        }
        
        // Update notes with general recommendations
        if !parsed.recommendations.isEmpty {
            let newNotes = parsed.recommendations
            if log.notes.isEmpty {
                log.notes = newNotes
            } else if !log.notes.contains(newNotes) {
                log.notes += "\n\nРекомендации ИИ:\n" + newNotes
            }
        }
        
        // Setup session
        let session = log.workout ?? WorkoutSession(exercises: [])
        if log.workout == nil {
            log.workout = session
            modelContext.insert(session)
        }
        
        // Add exercises to the session
        for (index, exercise) in parsed.exercises.enumerated() {
            exercise.orderIndex = index + 1
            session.exercises.append(exercise)
        }
        
        // Explicitly save the context
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save workout: \(error)")
        }
    }
    
    private func revealParsedExercises(count: Int) {
        for index in 0..<count {
            let delay = DispatchTimeInterval.milliseconds(index * 55)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard index < (parsedWorkout?.exercises.count ?? 0) else { return }
                
                withAnimation(.spring(response: 0.48, dampingFraction: 0.78, blendDuration: 0.12)) {
                    revealedExerciseIndices.insert(index)
                }
            }
        }
    }
}

#Preview("Parsed Workout") {
    let exercises = [
        Exercise(
            name: "Жим гантелей на наклонной",
            orderIndex: 1,
            sets: (1...4).map { WorkoutSet(setNumber: $0, plannedReps: 10) },
            plannedWeight: 28,
            notes: "",
            recommendations: "Контроль лопаток, без паузы внизу."
        ),
        Exercise(
            name: "Тяга верхнего блока",
            orderIndex: 2,
            sets: (1...3).map { WorkoutSet(setNumber: $0, plannedReps: 12) },
            plannedWeight: 65,
            notes: "",
            recommendations: "Веди локти вниз, не раскачивай корпус."
        ),
        Exercise(
            name: "Разведения в стороны",
            orderIndex: 3,
            sets: (1...3).map { WorkoutSet(setNumber: $0, plannedReps: 15) },
            plannedWeight: 10,
            notes: "",
            recommendations: "Последние повторы без читинга."
        )
    ]
    
    SmartPlanParserView(
        parsedWorkout: ParsedWorkout(
            exercises: exercises,
            recommendations: "Сегодня держи RIR 1-2 и не форсируй вес в первом упражнении."
        )
    )
    .modelContainer(for: [
        DailyLog.self,
        Meal.self,
        Supplement.self,
        WorkoutSession.self,
        Exercise.self,
        WorkoutSet.self,
        GymPass.self
    ], inMemory: true)
}
