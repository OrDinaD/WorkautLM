import Foundation
import ActivityKit

struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes during the activity
        var exerciseName: String
        var currentSetNumber: Int
        var totalSets: Int
        var weight: String
        var reps: String
        var isCompleted: Bool
    }

    // Static data that doesn't change
    var workoutName: String
}
