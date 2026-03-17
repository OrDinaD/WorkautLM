import SwiftUI
import SwiftData

@main
struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [
            DailyLog.self,
            Meal.self,
            Supplement.self,
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            FaceLog.self
        ])
    }
}
