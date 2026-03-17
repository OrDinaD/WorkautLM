import SwiftUI
import SwiftData

@main
struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            DailyLog.self,
            Meal.self,
            Supplement.self,
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self
        ])
    }
}
