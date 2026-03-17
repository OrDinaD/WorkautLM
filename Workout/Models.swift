import Foundation
import SwiftData

@Model
final class DailyLog {
    var date: Date
    var sleepDuration: Double // in hours
    var notes: String
    
    @Relationship(deleteRule: .cascade, inverse: \Meal.dailyLog)
    var meals: [Meal]
    
    @Relationship(deleteRule: .cascade, inverse: \Supplement.dailyLog)
    var supplements: [Supplement]
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.dailyLog)
    var workout: WorkoutSession?
    
    init(date: Date = Date(), sleepDuration: Double = 0, notes: String = "", meals: [Meal] = [], supplements: [Supplement] = [], workout: WorkoutSession? = nil) {
        self.date = date
        self.sleepDuration = sleepDuration
        self.notes = notes
        self.meals = meals
        self.supplements = supplements
        self.workout = workout
    }
}

@Model
final class Meal {
    var time: Date
    var foodDescription: String
    var dailyLog: DailyLog?
    
    init(time: Date = Date(), foodDescription: String = "", dailyLog: DailyLog? = nil) {
        self.time = time
        self.foodDescription = foodDescription
        self.dailyLog = dailyLog
    }
}

@Model
final class Supplement {
    var name: String
    var dosage: String
    var time: Date
    var isTaken: Bool
    var dailyLog: DailyLog?
    
    init(name: String = "", dosage: String = "", time: Date = Date(), isTaken: Bool = false, dailyLog: DailyLog? = nil) {
        self.name = name
        self.dosage = dosage
        self.time = time
        self.isTaken = isTaken
        self.dailyLog = dailyLog
    }
}

@Model
final class WorkoutSession {
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]
    
    var dailyLog: DailyLog?
    var startTime: Date?
    
    init(exercises: [Exercise] = [], startTime: Date = Date()) {
        self.exercises = exercises
        self.startTime = startTime
    }
}

@Model
final class Exercise {
    var name: String
    var orderIndex: Int? // Optional for migration
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]
    
    var plannedWeight: Double
    var plannedWeightString: String? // To store ranges like "25-30"
    var plannedRepsString: String?   // To store ranges like "12-15"
    var notes: String
    var recommendations: String? // Optional for migration
    var workout: WorkoutSession?
    
    init(name: String = "", orderIndex: Int? = 0, sets: [WorkoutSet] = [], plannedWeight: Double = 0, plannedWeightString: String? = nil, plannedRepsString: String? = nil, notes: String = "", recommendations: String? = "") {
        self.name = name
        self.orderIndex = orderIndex
        self.sets = sets
        self.plannedWeight = plannedWeight
        self.plannedWeightString = plannedWeightString
        self.plannedRepsString = plannedRepsString
        self.notes = notes
        self.recommendations = recommendations
    }
}

@Model
final class WorkoutSet {
    var setNumber: Int
    var plannedReps: Int
    var actualReps: Int?
    var actualWeight: Double?
    var isCompleted: Bool
    var completionTime: Date?
    var exercise: Exercise?
    
    init(setNumber: Int = 1, plannedReps: Int = 10, actualReps: Int? = nil, actualWeight: Double? = nil, isCompleted: Bool = false, completionTime: Date? = nil) {
        self.setNumber = setNumber
        self.plannedReps = plannedReps
        self.actualReps = actualReps
        self.actualWeight = actualWeight
        self.isCompleted = isCompleted
        self.completionTime = completionTime
    }
}
