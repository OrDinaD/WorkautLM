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
            
            // Работаем со строками таблицы Markdown (достаточно префикса |)
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
                        
                        let pattern = #"(\d+)\s*x\s*(\d+)"#
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                           let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
                            if let sR = Range(match.range(at: 1), in: normalized), 
                               let rR = Range(match.range(at: 2), in: normalized) {
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
                        plannedWeightString: displayWeight == "-" ? nil : displayWeight,
                        plannedRepsString: displayReps == "-" ? nil : displayReps,
                        notes: "",
                        recommendations: techNotes.replacingOccurrences(of: ". ", with: "\n"),
                        isWarmup: isWarmup
                    )
                    exercises.append(exercise)
                }
            } else {
                // Все, что не таблица — в общие рекомендации
                generalNotes.append(line)
            }
        }
        
        return ParsedWorkout(exercises: exercises, recommendations: generalNotes.joined(separator: "\n"))
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
