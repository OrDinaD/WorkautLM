import SwiftUI
import SwiftData
import ActivityKit
import Combine
import UserNotifications

struct ExportData: Identifiable {
    let id = UUID()
    let text: String
}

struct WorkoutExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var session: WorkoutSession
    
    @State private var exportData: ExportData?
    @State private var currentActivity: Activity<WorkoutAttributes>?
    
    @State private var restTimeRemaining = 90
    @State private var isRestTimerActive = false
    @State private var restEndTime: Date? = nil
    
    @StateObject private var hkManager = HealthKitManager()
    
    @State private var isCompletedSectionExpanded: Bool = false
    
    // For Exercise Replacement
    @State private var showingRenameAlert = false
    @State private var exerciseToRename: Exercise? = nil
    @State private var newExerciseName = ""
    
    @State private var recentlyCompletedExerciseIDs: Set<PersistentIdentifier> = []
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .bottom) {
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

                        let allExercises = session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })
                        let activeExercises = allExercises.filter { !$0.isCompleted || recentlyCompletedExerciseIDs.contains($0.id) }
                        let completedExercises = allExercises.filter { $0.isCompleted && !recentlyCompletedExerciseIDs.contains($0.id) }

                        // Active Exercises
                        ForEach(activeExercises) { exercise in
                            ExerciseCardView(
                                exercise: exercise,
                                onUpdate: updateActivity,
                                onSetCompleted: {
                                    handleSetCompleted(for: exercise)
                                },
                                onRename: {
                                    exerciseToRename = exercise
                                    newExerciseName = exercise.name
                                    showingRenameAlert = true
                                }
                            )
                                .matchedGeometryEffect(id: exercise.id, in: animation)
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }

                        // Completed Exercises Section
                        if !completedExercises.isEmpty {
                            Section {
                                DisclosureGroup(isExpanded: $isCompletedSectionExpanded) {
                                    ForEach(completedExercises) { exercise in
                                        ExerciseCardView(
                                            exercise: exercise,
                                            onUpdate: updateActivity,
                                            onSetCompleted: {
                                                handleSetCompleted(for: exercise)
                                            },
                                            onRename: {
                                                exerciseToRename = exercise
                                                newExerciseName = exercise.name
                                                showingRenameAlert = true
                                            }
                                        )
                                        .matchedGeometryEffect(id: exercise.id, in: animation)
                                        .listRowBackground(Color.black)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    }
                                } label: {
                                    HStack {
                                        Text("Выполненные")
                                            .font(.headline)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Text("\(completedExercises.count)")
                                            .font(.subheadline)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.2))
                                            .clipShape(Capsule())
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .listRowBackground(Color.black)
                                .tint(.gray)
                            }
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
                VStack {
                    RestTimerView(remainingTime: $restTimeRemaining, isActive: $isRestTimerActive, endTime: $restEndTime)
                        .padding(.bottom, 8)
                    
                    HStack {
                        Spacer()
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
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationTitle("Тренировка")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Заменить упражнение", isPresented: $showingRenameAlert) {
            TextField("Название упражнения", text: $newExerciseName)
            Button("Отмена", role: .cancel) { }
            Button("Сохранить") {
                if let exercise = exerciseToRename {
                    exercise.name = newExerciseName
                    updateActivity()
                }
            }
        } message: {
            Text("Если нужный тренажер занят, вы можете заменить его аналогом.")
        }
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
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .onAppear {
            // Синхронизируем состояние активности при входе на экран
            currentActivity = Activity<WorkoutAttributes>.activities.first
            requestNotificationPermission()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                updateRestTimerFromBackground()
            }
        }
    }

    // MARK: - Notification Logic
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func scheduleRestNotification(in seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Время отдыха вышло!"
        content.body = "Пора делать следующий подход."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "WorkoutRestTimer", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["WorkoutRestTimer"])
    }

    // MARK: - Timer Logic

    private func handleSetCompleted(for exercise: Exercise) {
        startRestTimer(seconds: 90)
        if exercise.isCompleted {
            recentlyCompletedExerciseIDs.insert(exercise.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    _ = recentlyCompletedExerciseIDs.remove(exercise.id)
                }
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                _ = recentlyCompletedExerciseIDs.remove(exercise.id)
            }
        }
    }

    private func startRestTimer(seconds: Int) {        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            restTimeRemaining = seconds
            restEndTime = Date().addingTimeInterval(TimeInterval(seconds))
            isRestTimerActive = true
        }
        scheduleRestNotification(in: seconds)
    }
    
    private func updateRestTimerFromBackground() {
        guard isRestTimerActive, let endTime = restEndTime else { return }
        let now = Date()
        if now >= endTime {
            isRestTimerActive = false
            restTimeRemaining = 0
        } else {
            restTimeRemaining = Int(endTime.timeIntervalSince(now))
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
                session.endTime = Date()
                hkManager.saveWorkout(session: session)
            }
        } else {
            session.startTime = Date()
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
        
        var markdown = "Тренировка: \(dateStr) (Начало: \(timeStr))\n\n"
        
        markdown += "| Упражнение | Подход | Вес | Повт | RPE | Заметки |\n"
        markdown += "|---|---|---|---|---|---|\n"
        
        for exercise in session.exercises.sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
            let sortedSets = exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
            for (index, set) in sortedSets.enumerated() {
                let weight = set.actualWeight ?? exercise.plannedWeight
                let reps = set.actualReps ?? set.plannedReps
                let rpe = "\(set.rpe ?? 8)"
                let status = set.isCompleted ? "" : "(Не выполнено) "
                
                let notes = index == 0 ? exercise.notes.replacingOccurrences(of: "\n", with: " ") : ""
                markdown += "| \(exercise.name) | \(set.setNumber) | \(weight) кг | \(status)\(reps) | \(rpe) | \(notes) |\n"
            }
        }
        
        exportData = ExportData(text: markdown)
    }
}

struct RestTimerView: View {
    @Binding var remainingTime: Int
    @Binding var isActive: Bool
    @Binding var endTime: Date?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        if isActive && remainingTime > 0 {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.purple)
                Text("Отдых: \(timeString(remainingTime))")
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
                    .foregroundStyle(.white)
                
                Button(action: { isActive = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.2))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.purple.opacity(0.5), lineWidth: 1))
            .onReceive(timer) { _ in
                if let endTime = endTime {
                    let now = Date()
                    if now >= endTime {
                        isActive = false
                        remainingTime = 0
                    } else {
                        remainingTime = Int(endTime.timeIntervalSince(now))
                    }
                }
            }
        }
    }
    
    func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
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
    var onSetCompleted: () -> Void
    var onRename: () -> Void
    
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
            HStack(alignment: .top) {
                Text("\(exercise.orderIndex ?? 0). \(exercise.name)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        UIPasteboard.general.string = exercise.name
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    .onLongPressGesture {
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                        onRename()
                    }
                
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
                if exercise.isWarmup {
                    Text("РАЗМИНКА").frame(width: 70, alignment: .leading)
                    Text("СКОРОСТЬ").frame(width: 80, alignment: .center)
                    Text("ВРЕМЯ").frame(width: 60, alignment: .center)
                } else {
                    Text("ПОДХОД").frame(width: 40, alignment: .leading)
                    Text("ВЕС").frame(width: 60, alignment: .center)
                    Text("ПОВТ").frame(width: 50, alignment: .center)
                    Text("RPE").frame(width: 50, alignment: .center)
                }
                Spacer()
                Text("ГОТОВО")
            }
            .font(.caption2)
            .bold()
            .foregroundStyle(.gray)
            
            // Sets List
            ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                SetRowView(set: set, onUpdate: onUpdate, onSetCompleted: onSetCompleted)
            }
        }
        .padding()
        .background(exercise.isCompleted ? Color(.systemGray5).opacity(0.1) : Color(.systemGray6).opacity(0.15))
        .grayscale(exercise.isCompleted ? 1.0 : 0.0)
        .opacity(exercise.isCompleted ? 0.8 : 1.0)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(exercise.isCompleted ? Color.gray.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SetRowView: View {
    @Bindable var set: WorkoutSet
    var onUpdate: () -> Void
    var onSetCompleted: () -> Void
    
    // Available weights
    let weights: [Double] = {
        var values: [Double] = []
        for i in 1...10 { values.append(Double(i)) }
        values.append(12.5); values.append(13.0)
        var current = 15.0
        while current <= 150.0 { values.append(current); current += 2.5 }
        return values
    }()
    
    // Available speeds (for warmup)
    let speeds: [Double] = {
        var values: [Double] = []
        var current = 1.0
        while current <= 25.0 { values.append(current); current += 0.5 }
        return values
    }()
    
    let repsRange = Array(1...50)
    let timeRange = Array(1...120) // up to 2 hours
    let rpeRange = Array(5...10)
    
    var body: some View {
        HStack {
            if let exercise = set.exercise, exercise.isWarmup {
                // Warmup UI: Speed and Time
                Text("Старт")
                    .font(.caption).bold()
                    .frame(width: 55, alignment: .leading)
                    .foregroundStyle(set.isCompleted ? .purple : .gray)
                
                // Speed Picker (reusing actualWeight)
                Menu {
                    Picker("Скорость", selection: Binding(
                        get: { set.actualWeight ?? 0 },
                        set: { set.actualWeight = $0; onUpdate() }
                    )) {
                        ForEach(speeds, id: \.self) { speed in
                            Text("\(speed, specifier: "%.1f") км/ч").tag(speed)
                        }
                    }
                } label: {
                    Text("\(set.actualWeight ?? 0, specifier: "%.1f")")
                        .font(.system(.subheadline, design: .monospaced)).bold()
                        .frame(width: 60).padding(6)
                        .background(Color.white.opacity(0.05)).cornerRadius(8)
                        .foregroundStyle(.white)
                }
                
                Spacer().frame(width: 20)
                
                // Time Picker (reusing actualReps)
                Menu {
                    Picker("Время", selection: Binding(
                        get: { set.actualReps ?? 5 },
                        set: { set.actualReps = $0; onUpdate() }
                    )) {
                        ForEach(timeRange, id: \.self) { mins in
                            Text("\(mins) мин").tag(mins)
                        }
                    }
                } label: {
                    Text("\(set.actualReps ?? 5)м")
                        .font(.system(.subheadline, design: .monospaced)).bold()
                        .frame(width: 50).padding(6)
                        .background(Color.white.opacity(0.05)).cornerRadius(8)
                        .foregroundStyle(.white)
                }
                
            } else {
                // Normal Exercise UI: Set, Weight, Reps, RPE
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
                        .foregroundStyle(.white)
                }
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
                onSetCompleted()
            } else {
                set.completionTime = nil
                onSetCompleted() // Trigger re-sort when unchecking
            }
            onUpdate() // Обновляем Live Activity
        }
    }
}
