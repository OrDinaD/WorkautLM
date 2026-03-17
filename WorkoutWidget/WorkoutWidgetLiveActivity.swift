import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// Атрибуты активности
struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var currentSetNumber: Int
        var totalSets: Int
        var weight: String
        var reps: String
        var isCompleted: Bool
    }
    var workoutName: String
}

struct WorkoutWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // UI для Экрана блокировки (Lock Screen)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.title)
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                        Text("Подход \(context.state.currentSetNumber) из \(context.state.totalSets)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(context.state.weight) кг")
                        .font(.title3.bold())
                        .foregroundStyle(.purple)
                }
                
                HStack {
                    Text("Цель: \(context.state.reps) повт")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    if #available(iOS 17.0, *) {
                        Button(intent: CompleteSetIntent()) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Готово")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.purple)

        } dynamicIsland: { context in
            DynamicIsland {
                // Раскрытый вид (Expanded)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.purple)
                        Text("Сет \(context.state.currentSetNumber)/\(context.state.totalSets)")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.weight)кг")
                        .font(.headline)
                        .foregroundStyle(.purple)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                        
                        if #available(iOS 17.0, *) {
                            Button(intent: CompleteSetIntent()) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Завершить подход")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .clipShape(Capsule()) // Максимальное закругление
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 5)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(.purple)
            } compactTrailing: {
                Text("\(context.state.currentSetNumber)/\(context.state.totalSets)")
                    .foregroundStyle(.purple)
            } minimal: {
                Text("\(context.state.currentSetNumber)")
                    .foregroundStyle(.purple)
            }
            .widgetURL(URL(string: "workoutapp://complete-set")) // URL для открытия приложения
            .keylineTint(Color.purple)
        }
    }
}

// Интент для обработки нажатия кнопки
@available(iOS 16.0, *)
struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Завершить подход"
    
    // Этот метод вызывается при нажатии на кнопку в Островке
    func perform() async throws -> some IntentResult {
        // Мы используем URL-схему, чтобы приложение открылось и обновило данные
        // В реальном iOS приложении это заставит систему проснуться
        return .result()
    }
}
