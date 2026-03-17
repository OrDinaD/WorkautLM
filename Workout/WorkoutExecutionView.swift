import SwiftUI
import SwiftData

struct ExportData: Identifiable {
    let id = UUID()
    let text: String
}

struct WorkoutExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    
    @State private var exportData: ExportData?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                if session.exercises.isEmpty {
                    ContentUnavailableView {
                        Label("Нет упражнений", systemImage: "list.bullet.clipboard")
                            .foregroundStyle(.purple)
                    } description: {
                        Text("Добавьте упражнения через Smart Parser, чтобы начать тренировку.")
                            .foregroundStyle(.gray)
                    }
                } else {
                    List {
                        Section {
                            DatePicker(
                                "Начало тренировки",
                                selection: Binding(
                                    get: { session.startTime ?? session.dailyLog?.date ?? Date() },
                                    set: { session.startTime = $0 }
                                ),
                                displayedComponents: [.hourAndMinute, .date]
                            )
                            .foregroundStyle(.white)
                            .tint(.purple)
                            .listRowBackground(Color.white.opacity(0.05))
                        } header: {
                            Text("Время и дата").foregroundStyle(.gray)
                        }

                        ForEach(session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })) { exercise in
                            ExerciseCardView(exercise: exercise)
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                }
            }
        }
        .navigationTitle("Тренировка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: prepareExport) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.purple)
                }
            }
        }
        .sheet(item: $exportData) { data in
            MarkdownExportView(text: data.text)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func prepareExport() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let date = session.startTime ?? session.dailyLog?.date ?? Date()
        let dateStr = formatter.string(from: date)
        let timeStr = timeFormatter.string(from: date)
        
        var markdown = "Тренировка: \(dateStr) (Начало: \(timeStr))\n\n"
        markdown += "| Упражнение | Подход | Вес | Повт | Заметки |\n"
        markdown += "|---|---|---|---|---|\n"
        
        for exercise in session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
            let sortedSets = exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
            for (index, set) in sortedSets.enumerated() {
                let weight = set.actualWeight ?? exercise.plannedWeight
                let reps = set.actualReps ?? set.plannedReps
                let status = set.isCompleted ? "" : "(Не выполнено) "
                
                // Only include notes on the first set row to avoid duplication
                let notes = index == 0 ? exercise.notes.replacingOccurrences(of: "\n", with: " ") : ""
                
                markdown += "| \(exercise.name) | \(set.setNumber) | \(weight) кг | \(status)\(reps) | \(notes) |\n"
            }
        }
        
        exportData = ExportData(text: markdown)
    }
}

struct MarkdownExportView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Экспорт Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }.foregroundStyle(.purple)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: text) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }
}

struct ExerciseCardView: View {
    @Bindable var exercise: Exercise
    @State private var isRecommendationsExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(exercise.orderIndex ?? 0). \(exercise.name)")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    if let weightStr = exercise.plannedWeightString, !weightStr.isEmpty {
                        Text(weightStr)
                    } else {
                        Text("\(exercise.plannedWeight, specifier: "%.1f")")
                        Text("кг")
                    }
                }
                .font(.subheadline)
                .bold()
                .foregroundStyle(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            }
            
            if let repsStr = exercise.plannedRepsString, !repsStr.isEmpty {
                Text("Цель: \(repsStr)")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.top, -8)
            }
            
            if let recs = exercise.recommendations, !recs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Рекомендации:")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.purple)
                    
                    Text(recs)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(isRecommendationsExpanded ? nil : 2)
                        .onTapGesture {
                            withAnimation {
                                isRecommendationsExpanded.toggle()
                            }
                        }
                    
                    Button(action: {
                        withAnimation {
                            isRecommendationsExpanded.toggle()
                        }
                    }) {
                        Text(isRecommendationsExpanded ? "Свернуть" : "Развернуть...")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .padding(.top, 2)
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
            
            // User Notes Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Мои ощущения:")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.gray)
                TextField("Как прошло упражнение?", text: $exercise.notes, axis: .vertical)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // Sets Table Header
            HStack {
                Text("ПОДХОД").frame(width: 50, alignment: .leading)
                Text("ВЕС").frame(width: 80, alignment: .center)
                Text("ПОВТ").frame(width: 80, alignment: .center)
                Spacer()
                Text("ГОТОВО")
            }
            .font(.caption2)
            .bold()
            .foregroundStyle(.gray)
            
            // Sets List
            ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                SetRowView(set: set)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    
    // Available weights: 1-10 with step 1, then 12.5, 13, 15, 17.5, 20... up to 150
    let weights: [Double] = {
        var values: [Double] = []
        for i in 1...10 { values.append(Double(i)) }
        values.append(12.5)
        values.append(13.0)
        var current = 15.0
        while current <= 150.0 {
            values.append(current)
            current += 2.5
        }
        return values
    }()
    
    let repsRange = Array(1...50)
    
    var body: some View {
        HStack {
            // Set Number
            Text("\(set.setNumber)")
                .font(.subheadline)
                .bold()
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(set.isCompleted ? .purple : .gray)
            
            // Weight Picker
            Menu {
                Picker("Вес", selection: Binding(
                    get: { set.actualWeight ?? set.exercise?.plannedWeight ?? 0 },
                    set: { set.actualWeight = $0 }
                )) {
                    ForEach(weights, id: \.self) { weight in
                        Text("\(weight, specifier: weight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f") кг")
                            .tag(weight)
                    }
                }
            } label: {
                Text("\(set.actualWeight ?? set.exercise?.plannedWeight ?? 0, specifier: (set.actualWeight ?? set.exercise?.plannedWeight ?? 0).truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f")")
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
                    .frame(width: 70)
                    .padding(6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundStyle(.white)
            }
            
            // Reps Picker
            Menu {
                Picker("Повт", selection: Binding(
                    get: { set.actualReps ?? set.plannedReps },
                    set: { set.actualReps = $0 }
                )) {
                    ForEach(repsRange, id: \.self) { rep in
                        Text("\(rep)")
                            .tag(rep)
                    }
                }
            } label: {
                Text("\(set.actualReps ?? set.plannedReps)")
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
                    .frame(width: 60)
                    .padding(6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            // Completion Checkbox
            Button(action: toggleCompletion) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(set.isCompleted ? Color.purple : Color.white.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    if set.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(set.isCompleted ? .white : .gray)
    }
    
    private func toggleCompletion() {
        withAnimation(.spring()) {
            set.isCompleted.toggle()
            if set.isCompleted {
                set.completionTime = Date()
                // Auto-fill actual values if they are empty
                if set.actualWeight == nil || set.actualWeight == 0 {
                    set.actualWeight = set.exercise?.plannedWeight
                }
                if set.actualReps == nil || set.actualReps == 0 {
                    set.actualReps = set.plannedReps
                }
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } else {
                set.completionTime = nil
            }
        }
    }
}
