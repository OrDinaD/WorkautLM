import SwiftUI
import SwiftData

struct SmartPlanParserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var logs: [DailyLog]
    
    @State private var rawText: String = ""
    @State private var parsedWorkout: ParsedWorkout? = nil
    
    private var todayLog: DailyLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    @State private var recommendationsExpanded: Bool = false

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
                
                if let exercises = parsedWorkout?.exercises, !exercises.isEmpty {
                    Section {
                        ForEach(0..<(parsedWorkout?.exercises.count ?? 0), id: \.self) { index in
                            exerciseEditRow(index: index)
                                .listRowBackground(Color.black)
                        }
                    } header: {
                        Text("Тренировка").foregroundStyle(.purple)
                    }
                }
            }
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            
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
        }
    }
    
    private func parseText() {
        withAnimation {
            parsedWorkout = PlanParser.parse(rawText)
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
        for exercise in parsed.exercises {
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
}
