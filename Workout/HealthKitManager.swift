import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    @Published var sleepDurationToday: Double = 0.0
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let typesToRead: Set = [sleepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            if success {
                self.fetchSleepData()
            }
        }
    }
    
    func fetchSleepData() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        // Логика получения сна:
        // Сон за "сегодня" — это тот, который завершился сегодня утром.
        // Берем период с 18:00 вчерашнего дня до текущего момента.
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let startDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 0, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKCategorySample], error == nil else {
                print("HealthKit Error or no samples: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            // 1. Фильтруем только то, что является именно сном (не просто "в постели")
            let sleepStages: [HKCategoryValueSleepAnalysis] = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]
            let relevantSamples = samples.filter { sample in
                sleepStages.map { $0.rawValue }.contains(sample.value)
            }
            
            // 2. Умное объединение пересекающихся интервалов (если есть данные с часов и телефона одновременно)
            let sortedSamples = relevantSamples.sorted { $0.startDate < $1.startDate }
            var totalSeconds: TimeInterval = 0
            var currentIntervalStart: Date?
            var currentIntervalEnd: Date?
            
            for sample in sortedSamples {
                if let start = currentIntervalStart, let end = currentIntervalEnd {
                    if sample.startDate < end {
                        // Есть пересечение, расширяем текущий интервал
                        currentIntervalEnd = max(end, sample.endDate)
                    } else {
                        // Нет пересечения, прибавляем старый и начинаем новый
                        totalSeconds += end.timeIntervalSince(start)
                        currentIntervalStart = sample.startDate
                        currentIntervalEnd = sample.endDate
                    }
                } else {
                    currentIntervalStart = sample.startDate
                    currentIntervalEnd = sample.endDate
                }
            }
            
            // Прибавляем последний интервал
            if let start = currentIntervalStart, let end = currentIntervalEnd {
                totalSeconds += end.timeIntervalSince(start)
            }
            
            print("Total accurate sleep seconds: \(totalSeconds)")
            
            DispatchQueue.main.async {
                self.sleepDurationToday = totalSeconds / 3600.0
            }
        }
        
        healthStore.execute(query)
    }
}
