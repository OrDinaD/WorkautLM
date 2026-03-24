import SwiftUI
import SwiftData
import ActivityKit

struct ExportData: Identifiable {
    let id = UUID()
    let text: String
}

struct WorkoutExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    
    @State private var exportData: ExportData?
    @State private var currentActivity: Activity<WorkoutAttributes>?
    @State private var showingPreWorkoutMetrics = false
    @State private var showingPostWorkoutMetrics = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                            ExerciseCardView(exercise: exercise, onUpdate: updateActivity)
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        
                        // Отступ снизу для кнопки
                        Color.clear.frame(height: 80).listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            
            // Floating Action Button для режима тренировки
            if !session.exercises.isEmpty {
                Button(action: toggleLiveActivity) {
                    HStack {
                        Image(systemName: currentActivity == nil ? "play.fill" : "stop.fill")
                        Text(currentActivity == nil ? "Начать режим тренировки" : "Завершить режим")
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(currentActivity == nil ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: (currentActivity == nil ? Color.green : Color.red).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .transition(.scale.combined(with: .opacity))
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
        .sheet(isPresented: $showingPreWorkoutMetrics) {
            PreWorkoutMetricsView(session: session)
        }
        .sheet(isPresented: $showingPostWorkoutMetrics) {
            PostWorkoutMetricsView(session: session)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .onAppear {
            // Синхронизируем состояние активности при входе на экран
            currentActivity = Activity<WorkoutAttributes>.activities.first
        }
    }

    // MARK: - Live Activity Logic
    
    private func toggleLiveActivity() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let activity = currentActivity {
            let state = activity.content.state
            Task {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
                currentActivity = nil
                showingPostWorkoutMetrics = true // Show post-workout metrics when finishing activity
            }
        } else {
            showingPreWorkoutMetrics = true // Show pre-workout metrics before starting activity
            startActivity()
        }
    }
    
    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are disabled")
            return
        }
        
        let sortedExercises = session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })
        
        // Ищем текущее упражнение (где есть незаконченные подходы)
        let activeExercise = sortedExercises.first(where: { exercise in
            exercise.sets.contains { !$0.isCompleted }
        }) ?? sortedExercises.first
        
        guard let exercise = activeExercise else { return }
        
        let sortedSets = exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
        let currentSet = sortedSets.first(where: { !$0.isCompleted }) ?? sortedSets.first!
        
        let attributes = WorkoutAttributes(workoutName: "Тренировка")
        
        let weightVal = currentSet.actualWeight ?? exercise.plannedWeight
        let weightStr = weightVal == 0 ? "-" : (weightVal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", weightVal) : String(format: "%.1f", weightVal))
        
        let initialState = WorkoutAttributes.ContentState(
            exerciseName: exercise.name,
            currentSetNumber: currentSet.setNumber,
            totalSets: exercise.sets.count,
            weight: weightStr,
            reps: exercise.plannedRepsString ?? "\(currentSet.actualReps ?? currentSet.plannedReps)",
            isCompleted: false
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
            print("Activity started: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func updateActivity() {
        guard let activity = currentActivity else { return }
        
        let sortedExercises = session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })
        
        guard let activeExercise = sortedExercises.first(where: { exercise in
            exercise.sets.contains { !$0.isCompleted }
        }) ?? sortedExercises.last else { return }
        
        let sortedSets = activeExercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
        let currentSet = sortedSets.first(where: { !$0.isCompleted }) ?? sortedSets.last!
        
        let weightVal = currentSet.actualWeight ?? activeExercise.plannedWeight
        let weightStr = weightVal == 0 ? "-" : (weightVal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", weightVal) : String(format: "%.1f", weightVal))
        
        let updatedState = WorkoutAttributes.ContentState(
            exerciseName: activeExercise.name,
            currentSetNumber: currentSet.setNumber,
            totalSets: activeExercise.sets.count,
            weight: weightStr,
            reps: activeExercise.plannedRepsString ?? "\(currentSet.actualReps ?? currentSet.plannedReps)",
            isCompleted: false
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        }
    }

    private func prepareExport() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let date = session.startTime ?? session.dailyLog?.date ?? Date()
        let dateStr = formatter.string(from: date)
        let timeStr = timeFormatter.string(from: date)
        
        var markdown = "Тренировка: \(dateStr) (Начало: \(timeStr))\n"
        markdown += "Сон: \(String(format: "%.1f", session.sleepHours)) ч, Стресс: \(session.stressLevel == 0 ? "Низкий" : (session.stressLevel == 1 ? "Средний" : "Высокий"))\n\n"
        
        markdown += "| Упражнение | Подход | Вес | Повт | RPE | Заметки |\n"
        markdown += "|---|---|---|---|---|---|\n"
        
        for exercise in session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
            let sortedSets = exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
            for (index, set) in sortedSets.enumerated() {
                let weight = set.actualWeight ?? exercise.plannedWeight
                let reps = set.actualReps ?? set.plannedReps
                let rpe = set.rpe != nil ? "\(set.rpe!)" : "-"
                let status = set.isCompleted ? "" : "(Не выполнено) "
                
                let notes = index == 0 ? exercise.notes.replacingOccurrences(of: "\n", with: " ") : ""
                markdown += "| \(exercise.name) | \(set.setNumber) | \(weight) кг | \(status)\(reps) | \(rpe) | \(notes) |\n"
            }
        }
        
        if let pump = session.pump {
            markdown += "\nОценка после:\n- Памп: \(pump)\n"
            markdown += "- Напряжение: \(session.tension ?? 0)\n"
            markdown += "- Крепатура: \(session.soreness ?? 0)\n"
        }
        
        exportData = ExportData(text: markdown)
    }
}

// MARK: - Metrics Views

struct PreWorkoutMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 30) {
                    VStack(alignment: .leading) {
                        Text("Качество сна (часы)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Stepper("\(session.sleepHours, specifier: "%.1f") ч", value: $session.sleepHours, in: 4...12, step: 0.5)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Уровень стресса")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Picker("Стресс", selection: $session.stressLevel) {
                            Text("Низкий").tag(0)
                            Text("Средний").tag(1)
                            Text("Высокий").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button("Начать тренировку") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .navigationTitle("Пре-воркаут метрики")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

struct PostWorkoutMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 25) {
                        MetricSelector(title: "Памп", description: "Наполненность мышц", value: Binding(get: { session.pump ?? 1 }, set: { session.pump = $0 }))
                        MetricSelector(title: "Напряжение", description: "Чувство целевых мышц", value: Binding(get: { session.tension ?? 1 }, set: { session.tension = $0 }))
                        MetricSelector(title: "Крепатура", description: "Утомление и боль", value: Binding(get: { session.soreness ?? 1 }, set: { session.soreness = $0 }))
                        
                        Spacer()
                        
                        Button("Завершить") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.large)
                        .padding(.top, 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Итоги тренировки (MEV)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

struct MetricSelector: View {
    let title: String
    let description: String
    @Binding var value: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(description)
                .font(.caption)
                .foregroundStyle(.gray)
            
            Picker(title, selection: $value) {
                Text("0 - Нет").tag(0)
                Text("1 - Норма").tag(1)
                Text("2 - Предел").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.top, 5)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Subviews

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
    var onUpdate: () -> Void
    
    private var processedRecommendations: AttributedString {
        guard let recs = exercise.recommendations else { return AttributedString("") }
        // Удаляем ссылки вида [1], [2] и т.д.
        let cleaned = recs.replacingOccurrences(of: #"\s*\[\d+\]"#, with: "", options: .regularExpression)
        
        do {
            // Поддержка Markdown (включая **жирный**)
            return try AttributedString(markdown: cleaned)
        } catch {
            return AttributedString(cleaned)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Button(action: {
                    UIPasteboard.general.string = exercise.name
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Text("\(exercise.orderIndex ?? 0). \(exercise.name)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.purple.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                
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
                    HStack {
                        Text("Рекомендации:")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.purple)
                        Spacer()
                    }
                    
                    Text(processedRecommendations)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(isRecommendationsExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: isRecommendationsExpanded)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isRecommendationsExpanded.toggle()
                            }
                        }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("ПОДХОД").frame(width: 30, alignment: .leading)
                Text("ВЕС").frame(width: 60, alignment: .center)
                Text("ПОВТ").frame(width: 50, alignment: .center)
                Text("RPE").frame(width: 50, alignment: .center)
                Spacer()
                Text("ГОТОВО")
            }
            .font(.caption2)
            .bold()
            .foregroundStyle(.gray)
            
            // Sets List
            ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                SetRowView(set: set, onUpdate: onUpdate)
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
    var onUpdate: () -> Void
    
    // Available weights
    let weights: [Double] = {
        var values: [Double] = []
        for i in 1...10 { values.append(Double(i)) }
        values.append(12.5); values.append(13.0)
        var current = 15.0
        while current <= 150.0 { values.append(current); current += 2.5 }
        return values
    }()
    
    let repsRange = Array(1...50)
    let rpeRange = Array(5...10)
    
    var body: some View {
        HStack {
            // Set Number
            Text("\(set.setNumber)")
                .font(.subheadline)
                .bold()
                .frame(width: 25, alignment: .leading)
                .foregroundStyle(set.isCompleted ? .purple : .gray)
            
            // Weight Picker
            Menu {
                Picker("Вес", selection: Binding(
                    get: { set.actualWeight ?? set.exercise?.plannedWeight ?? 0 },
                    set: { newValue in
                        set.actualWeight = newValue
                        autoFillDown(weight: newValue)
                        onUpdate()
                    }
                )) {
                    ForEach(weights, id: \.self) { weight in
                        Text("\(weight, specifier: weight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f") кг").tag(weight)
                    }
                }
            } label: {
                Text("\(set.actualWeight ?? set.exercise?.plannedWeight ?? 0, specifier: (set.actualWeight ?? set.exercise?.plannedWeight ?? 0).truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f")")
                    .font(.system(.subheadline, design: .monospaced)).bold()
                    .frame(width: 55).padding(6)
                    .background(Color.white.opacity(0.05)).cornerRadius(8)
                    .foregroundStyle(.white)
            }
            
            // Reps Picker
            Menu {
                Picker("Повт", selection: Binding(
                    get: { set.actualReps ?? set.plannedReps },
                    set: { newValue in
                        set.actualReps = newValue
                        autoFillDown(reps: newValue)
                        onUpdate()
                    }
                )) {
                    ForEach(repsRange, id: \.self) { rep in
                        Text("\(rep)").tag(rep)
                    }
                }
            } label: {
                Text("\(set.actualReps ?? set.plannedReps)")
                    .font(.system(.subheadline, design: .monospaced)).bold()
                    .frame(width: 45).padding(6)
                    .background(Color.white.opacity(0.05)).cornerRadius(8)
                    .foregroundStyle(.white)
            }
            
            // RPE Picker
            Menu {
                Picker("RPE", selection: Binding(
                    get: { set.rpe ?? 8 },
                    set: { newValue in
                        set.rpe = newValue
                        autoFillDown(rpe: newValue)
                        onUpdate()
                    }
                )) {
                    ForEach(rpeRange, id: \.self) { val in
                        Text("\(val)").tag(val)
                    }
                }
            } label: {
                Text("\(set.rpe ?? 8)")
                    .font(.system(.subheadline, design: .monospaced)).bold()
                    .frame(width: 40).padding(6)
                    .background(Color.white.opacity(0.05)).cornerRadius(8)
                    .foregroundStyle(set.rpe != nil ? .purple : .white)
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
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(set.isCompleted ? .white : .gray)
    }
    
    private func autoFillDown(weight: Double? = nil, reps: Int? = nil, rpe: Int? = nil) {
        guard let exercise = set.exercise else { return }
        
        // Находим все подходы этого упражнения, идущие после текущего и еще не выполненные
        for otherSet in exercise.sets {
            if otherSet.setNumber > set.setNumber && !otherSet.isCompleted {
                if let weight = weight {
                    otherSet.actualWeight = weight
                }
                if let reps = reps {
                    otherSet.actualReps = reps
                }
                if let rpe = rpe {
                    otherSet.rpe = rpe
                }
            }
        }
    }
    
    private func toggleCompletion() {
        withAnimation(.spring()) {
            set.isCompleted.toggle()
            if set.isCompleted {
                set.completionTime = Date()
                if set.actualWeight == nil || set.actualWeight == 0 { set.actualWeight = set.exercise?.plannedWeight }
                if set.actualReps == nil || set.actualReps == 0 { set.actualReps = set.plannedReps }
                let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
            } else {
                set.completionTime = nil
            }
            onUpdate() // Обновляем Live Activity
        }
    }
}
