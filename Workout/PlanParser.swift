import Foundation

struct ParsedWorkout {
    var exercises: [Exercise]
    var recommendations: String
}

class PlanParser {
    static func parse(_ text: String) -> ParsedWorkout {
        var exercises: [Exercise] = []
        var generalNotes: [String] = []
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // 1. Markdown Table Parsing
            if trimmed.hasPrefix("|") {
                // Пропускаем разделители и заголовки. 
                // Ищем как минимум два дефиса подряд, чтобы не спутать с прочерком '-' в данных
                if trimmed.replacingOccurrences(of: " ", with: "").contains("--|") || 
                   trimmed.contains("Упражнение") || 
                   trimmed.lowercased().contains("exercise") {
                    continue
                }
                
                let components = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if components.count >= 2 {
                    // 1. Имя упражнения
                    var name = components[0].replacingOccurrences(of: "**", with: "")
                    if let range = name.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                        name.removeSubrange(range)
                    }
                    name = name.trimmingCharacters(in: .whitespaces)
                    
                    let setsRepsStr = components.count > 1 ? components[1] : ""
                    let weightStr = components.count > 2 ? components[2] : ""
                    let techNotes = components.count > 3 ? components[3] : ""
                    
                    parseAndAddExercise(name: name, setsRepsStr: setsRepsStr, weightStr: weightStr, techNotes: techNotes, exercises: &exercises)
                }
            } 
            // 2. List-based Parsing (e.g., "1. Bench Press: 3x10 @ 60kg" or "- Squat: 3 sets of 8")
            else if let listMatch = try? NSRegularExpression(pattern: #"^[\d\.\-\*\s]*([A-Za-zА-Яа-я].*?):?\s*(.*)$"#).firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
                
                let nsString = trimmed as NSString
                let namePart = nsString.substring(with: listMatch.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let detailPart = nsString.substring(with: listMatch.range(at: 2)).trimmingCharacters(in: .whitespaces)
                
                if !detailPart.isEmpty && (detailPart.contains("x") || detailPart.contains("х") || detailPart.lowercased().contains("set") || detailPart.lowercased().contains("подход")) {
                    // Try to extract weight from detailPart if it contains "@" or "kg"
                    var weightStr = ""
                    var setsRepsStr = detailPart
                    
                    if let weightRange = detailPart.range(of: #"(@|на|at|weight:|вес:)\s*(\d+.*)$"#, options: [.regularExpression, .caseInsensitive]) {
                        weightStr = String(detailPart[weightRange]).replacingOccurrences(of: #"(@|на|at|weight:|вес:)"#, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespaces)
                        setsRepsStr = detailPart.replacingCharacters(in: weightRange, with: "").trimmingCharacters(in: .whitespaces)
                    } else if let kgRange = detailPart.range(of: #"\d+\s*(kg|кг)"#, options: .regularExpression) {
                        weightStr = String(detailPart[kgRange])
                        setsRepsStr = detailPart.replacingCharacters(in: kgRange, with: "").trimmingCharacters(in: .whitespaces)
                    }
                    
                    parseAndAddExercise(name: namePart, setsRepsStr: setsRepsStr, weightStr: weightStr, techNotes: "", exercises: &exercises)
                } else {
                    generalNotes.append(line)
                }
            }
            else {
                // Все, что не таблица и не список — в общие рекомендации
                generalNotes.append(line)
            }
        }
        
        return ParsedWorkout(exercises: exercises, recommendations: generalNotes.joined(separator: "\n"))
    }
    
    private static func parseAndAddExercise(name: String, setsRepsStr: String, weightStr: String, techNotes: String, exercises: inout [Exercise]) {
        // 2. Детекция разминки (более широкая)
        let isWarmup = setsRepsStr.lowercased().contains("мин") || 
                       setsRepsStr.lowercased().contains("min") ||
                       name.lowercased().contains("разминка") ||
                       name.lowercased().contains("разогрев") ||
                       name.lowercased().contains("warmup")
        
        // 3. Парсинг веса
        let weightValue = extractFirstNumber(from: weightStr)
        let displayWeight = weightStr.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        
        // 4. Парсинг подходов
        var setsCount = 1
        var repsCount = 1
        let displayReps = setsRepsStr.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        
        if isWarmup {
            setsCount = 1
            repsCount = 1
        } else {
            // Чистим от markdown и нормализуем 'х'
            let normalized = displayReps.lowercased().replacingOccurrences(of: "х", with: "x")
            
            let pattern = #"(\d+)\s*(x|sets? of|подхода?|подходов)\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
                if let sR = Range(match.range(at: 1), in: normalized), 
                   let rR = Range(match.range(at: 3), in: normalized) {
                    setsCount = Int(normalized[sR]) ?? 1
                    repsCount = Int(normalized[rR]) ?? 10
                }
            } else {
                // Если это просто число или диапазон (например "10-15"), берем первое число
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
