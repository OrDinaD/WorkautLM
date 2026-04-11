import SwiftUI
import SwiftData
import UserNotifications

@main
struct WorkoutApp: App {
    init() {
        // Очищаем все запланированные уведомления (включая старые напоминания про лицо)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("All pending notifications cleared.")
    }
    
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
            GymPass.self
        ])
    }
}
