import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    init() {
        manager.deviceMotionUpdateInterval = 1/60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            self?.pitch = motion.attitude.pitch
            self?.roll = motion.attitude.roll
        }
    }
}

struct GymPassView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymPass.addedDate, order: .reverse) private var passes: [GymPass]
    
    @StateObject private var motion = MotionManager()
    @State private var showingEditSheet = false
    
    var activePass: GymPass? {
        passes.first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if let pass = activePass {
                    passCard(for: pass)
                } else {
                    // Empty state card
                    VStack {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 10)
                        Text("Нет активного абонемента")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Добавить абонемент") {
                            showingEditSheet = true
                        }
                        .padding(.top, 10)
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Пропуск")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showingEditSheet) {
                GymPassEditView()
            }
        }
    }
    
    @ViewBuilder
    func passCard(for pass: GymPass) -> some View {
        VStack(spacing: 20) {
            // Gym Pass Card
            VStack(spacing: 20) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ARGUMENT")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("ФИТНЕС-ЦЕНТР")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 30)
                .padding(.horizontal, 25)
                
                // Barcode
                VStack(spacing: 8) {
                    if let barcodeImage = generateBarcode(from: pass.number) {
                        Image(uiImage: barcodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(4)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 100)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .overlay(Text("Неверный формат штрихкода").foregroundColor(.white))
                    }
                    
                    Text(pass.number)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 20/255, green: 50/255, blue: 160/255))
                    
                    // Tilt-responsive shimmer effect
                    GeometryReader { geo in
                        let shimmerX = CGFloat(motion.roll) * 1.5
                        let shimmerY = CGFloat(motion.pitch) * 1.5
                        
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.05),
                                .white.opacity(0.2),
                                .white.opacity(0.05),
                                .clear
                            ]),
                            startPoint: UnitPoint(x: 0.5 - shimmerX, y: 0.5 - shimmerY),
                            endPoint: UnitPoint(x: 0.5 + shimmerX, y: 0.5 + shimmerY)
                        )
                        .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
            .rotation3DEffect(.degrees(motion.roll * 10), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(-motion.pitch * 10), axis: (x: 1, y: 0, z: 0))
            
            // Validity Status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Срок действия")
                        .font(.headline)
                    Spacer()
                    Text(dateString(for: pass))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        Capsule()
                            .fill(
                                LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * currentProgress(for: pass), height: 12)
                    }
                }
                .frame(height: 12)
                
                Text(remainingDaysMessage(for: pass))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 25)
        }
    }
    
    func generateBarcode(from string: String) -> UIImage? {
        if string.isEmpty { return nil }
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    func dateString(for pass: GymPass) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        return "\(formatter.string(from: pass.startDate)) - \(formatter.string(from: pass.endDate))"
    }
    
    func currentProgress(for pass: GymPass) -> CGFloat {
        let now = Date()
        guard now >= pass.startDate else { return 0 }
        guard now <= pass.endDate else { return 1 }
        
        let total = pass.endDate.timeIntervalSince(pass.startDate)
        let elapsed = now.timeIntervalSince(pass.startDate)
        return CGFloat(elapsed / total)
    }
    
    func remainingDaysMessage(for pass: GymPass) -> String {
        let now = Date()
        if now < pass.startDate {
            return "Абонемент еще не начал действовать"
        }
        if now > pass.endDate {
            return "Срок действия абонемента истек"
        }
        
        let calendar = Calendar.current
        let startOfDayNow = calendar.startOfDay(for: now)
        let startOfDayEnd = calendar.startOfDay(for: pass.endDate)
        let components = calendar.dateComponents([.day], from: startOfDayNow, to: startOfDayEnd)
        if let days = components.day {
            return "Осталось \(days) дней"
        }
        return ""
    }
}

struct GymPassEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GymPass.addedDate, order: .reverse) private var passes: [GymPass]
    
    @State private var newNumber: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var isShowingAdd = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Новый абонемент / Продление")) {
                    if isShowingAdd {
                        TextField("Номер штрихкода", text: $newNumber)
                            .keyboardType(.numberPad)
                        DatePicker("Начало", selection: $startDate, displayedComponents: .date)
                        DatePicker("Конец", selection: $endDate, displayedComponents: .date)
                        
                        Button("Сохранить") {
                            addPass()
                            isShowingAdd = false
                        }
                        .disabled(newNumber.isEmpty)
                        .foregroundColor(.blue)
                        
                        Button("Отмена") {
                            isShowingAdd = false
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Добавить / Продлить абонемент") {
                            if let lastPass = passes.first {
                                newNumber = lastPass.number
                                startDate = Date()
                                endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                            }
                            isShowingAdd = true
                        }
                    }
                }
                
                Section(header: Text("История абонементов")) {
                    if passes.isEmpty {
                        Text("Нет сохраненных абонементов")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(passes) { pass in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Штрихкод: \(pass.number)")
                                    .font(.headline)
                                HStack {
                                    Text("\(formatDate(pass.startDate)) - \(formatDate(pass.endDate))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if pass == passes.first {
                                        Text("Активен")
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.green.opacity(0.2))
                                            .foregroundColor(.green)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deletePasses)
                    }
                }
            }
            .navigationTitle("Управление пропуском")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addPass() {
        let newPass = GymPass(number: newNumber, startDate: startDate, endDate: endDate, addedDate: Date())
        modelContext.insert(newPass)
    }
    
    private func deletePasses(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(passes[index])
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    GymPassView()
        .modelContainer(for: GymPass.self, inMemory: true)
}
