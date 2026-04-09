import Foundation

struct ParsedWorkout {
    var exercises: [Exercise]
    var recommendations: String
}

class PlanParser {
    static func parse(_ text: String) -> ParsedWorkout {
        var exercises: [Exercise] = []
        var generalNotes: [String] = []
        
        let skipNames = ["отдых", "rest", "break", "пауза"]
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let lowerTrimmed = trimmed.lowercased()
            
            // 0. Skip obvious headers or system lines
            let headers = ["упражнение", "подходы", "целевой вес", "техника и заметки", "exercise", "sets", "reps", "weight", "notes"]
            if headers.contains(where: { lowerTrimmed.contains($0) }) && !lowerTrimmed.contains("x") && !lowerTrimmed.contains("х") {
                generalNotes.append(line)
                continue
            }

            // 1. Table Detection (with or without leading/trailing pipes)
            if trimmed.contains("|") {
                // Skip separators/headers
                if (trimmed.contains("---") && trimmed.contains("|")) || 
                   trimmed.contains("Упражнение") || 
                   trimmed.lowercased().contains("exercise") {
                    continue
                }
                
                let components = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if components.count >= 2 {
                    var name = components[0].replacingOccurrences(of: "**", with: "")
                    if let range = name.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                        name.removeSubrange(range)
                    }
                    name = name.trimmingCharacters(in: .whitespaces)
                    
                    if skipNames.contains(where: { name.lowercased().hasPrefix($0) }) {
                        generalNotes.append(line)
                        continue
                    }
                    
                    let setsRepsStr = components.count > 1 ? components[1] : ""
                    let weightStr = components.count > 2 ? components[2] : ""
                    let techNotes = components.count > 3 ? components[3] : ""
                    
                    // Simple validation: name should not be too short and setsRepsStr should contain some number or 'x'
                    if !name.isEmpty && (setsRepsStr.rangeOfCharacter(from: .decimalDigits) != nil || setsRepsStr.contains("x") || setsRepsStr.contains("х")) {
                        parseAndAddExercise(name: name, setsRepsStr: setsRepsStr, weightStr: weightStr, techNotes: techNotes, exercises: &exercises)
                        continue 
                    }
                }
            }
            
            // 2. List-based Parsing
            // Flexible pattern for exercise details: "3x10", "3 sets of 10", "10 min"
            let detailPattern = #"(?i)(\d+)\s*(x|х|sets?(\s+of)?|подхода?|подходов|reps|повт|раз?)\s*(\d+)|(\d+)\s*(min|мин)"#
            
            if let regex = try? NSRegularExpression(pattern: detailPattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
                
                let nsString = trimmed as NSString
                let detailRange = match.range
                let namePartRaw = nsString.substring(to: detailRange.location)
                let detailPart = nsString.substring(from: detailRange.location)
                
                var name = namePartRaw.trimmingCharacters(in: CharacterSet(charactersIn: ":-–— ").union(.whitespacesAndNewlines))
                // Remove bullets/numbers from the start of the name
                if let bulletRange = name.range(of: #"^[\d\.\-\*\s]*"#, options: .regularExpression) {
                    name.removeSubrange(bulletRange)
                }
                name = name.trimmingCharacters(in: .whitespaces)
                
                if !name.isEmpty {
                    if skipNames.contains(where: { name.lowercased().hasPrefix($0) }) {
                        generalNotes.append(line)
                        continue
                    }
                    
                    var weightStr = ""
                    var setsRepsStr = detailPart
                    
                    if let weightRange = detailPart.range(of: #"(@|на|at|weight:|вес:)\s*(\d+.*)$"#, options: [.regularExpression, .caseInsensitive]) {
                         weightStr = String(detailPart[weightRange]).replacingOccurrences(of: #"(@|на|at|weight:|вес:)"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespaces)
                         setsRepsStr = detailPart.replacingCharacters(in: weightRange, with: "").trimmingCharacters(in: .whitespaces)
                    } else if let kgRange = detailPart.range(of: #"\d+\s*(kg|кг|lb|фунт)"#, options: .regularExpression) {
                         weightStr = String(detailPart[kgRange])
                         setsRepsStr = detailPart.replacingCharacters(in: kgRange, with: "").trimmingCharacters(in: .whitespaces)
                    }
                    
                    parseAndAddExercise(name: name, setsRepsStr: setsRepsStr, weightStr: weightStr, techNotes: "", exercises: &exercises)
                    continue
                }
            }
            
            // 3. Fallback: Everything else goes to generalNotes
            generalNotes.append(line)
        }
        
        return ParsedWorkout(exercises: exercises, recommendations: generalNotes.joined(separator: "\n"))
    }
    
    private static func parseAndAddExercise(name: String, setsRepsStr: String, weightStr: String, techNotes: String, exercises: inout [Exercise]) {
        // 1. Detection of warmup
        let isWarmup = setsRepsStr.lowercased().contains("мин") || 
                       setsRepsStr.lowercased().contains("min") ||
                       name.lowercased().contains("разминка") ||
                       name.lowercased().contains("разогрев") ||
                       name.lowercased().contains("warmup")
        
        // 2. Weight Parsing
        let weightValue = extractFirstNumber(from: weightStr)
        let displayWeight = weightStr.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        
        // 3. Sets/Reps Parsing
        var setsCount = 1
        var repsCount = 1
        let displayReps = setsRepsStr.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        
        if isWarmup {
            setsCount = 1
            repsCount = 1
        } else {
            // Clean markdown and normalize 'x'
            let normalized = displayReps.lowercased().replacingOccurrences(of: "х", with: "x")
            
            // Pattern to capture sets and reps (handles "sets of")
            let pattern = #"(\d+)\s*(x|sets?(\s+of)?|подхода?|подходов)\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
                if let sR = Range(match.range(at: 1), in: normalized), 
                   let rR = Range(match.range(at: 4), in: normalized) {
                    setsCount = Int(normalized[sR]) ?? 1
                    repsCount = Int(normalized[rR]) ?? 10
                }
            } else {
                // If just a number or range ("10-15"), take the first number
                let components = normalized.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
                if let firstNumStr = components.first(where: { !$0.isEmpty }), 
                   let val = Int(firstNumStr) {
                    repsCount = val
                }
            }
        }
        
        var workoutSets: [WorkoutSet] = []
        for i in 1...max(1, setsCount) {
            workoutSets.append(WorkoutSet(setNumber: i, plannedReps: repsCount))
        }
        
        let exercise = Exercise(
            name: name,
            orderIndex: exercises.count + 1,
            sets: workoutSets,
            plannedWeight: weightValue,
            plannedWeightString: displayWeight.isEmpty || displayWeight == "-" ? nil : displayWeight,
            plannedRepsString: displayReps.isEmpty || displayReps == "-" ? nil : displayReps,
            notes: "",
            recommendations: techNotes.replacingOccurrences(of: ". ", with: "\n"),
            isWarmup: isWarmup
        )
        exercises.append(exercise)
    }
    
    private static func extractFirstNumber(from text: String) -> Double {
        let cleaned = text.lowercased().replacingOccurrences(of: ",", with: ".")
        let components = cleaned.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
        if let firstNumStr = components.first(where: { !$0.isEmpty }), let val = Double(firstNumStr) {
            return val
        }
        return 0.0
    }
}
