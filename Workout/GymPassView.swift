import SwiftUI
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
    let barcodeData = "4813664623609" // EAN-13 from image
    let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 13))!
    let endDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 7))!
    
    @StateObject private var motion = MotionManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
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
                        if let barcodeImage = generateBarcode(from: barcodeData) {
                            Image(uiImage: barcodeImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                        
                        Text(barcodeData)
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
                        Text("13.03 - 07.04")
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
                                .frame(width: geo.size.width * currentProgress(), height: 12)
                        }
                    }
                    .frame(height: 12)
                    
                    Text(remainingDaysMessage())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 25)
                
                Spacer()
            }
            .navigationTitle("Пропуск")
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
    }
    
    func generateBarcode(from string: String) -> UIImage? {
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
    
    func currentProgress() -> CGFloat {
        let now = Date()
        guard now >= startDate else { return 0 }
        guard now <= endDate else { return 1 }
        
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = now.timeIntervalSince(startDate)
        return CGFloat(elapsed / total)
    }
    
    func remainingDaysMessage() -> String {
        let now = Date()
        if now < startDate {
            return "Абонемент еще не начал действовать"
        }
        if now > endDate {
            return "Срок действия абонемента истек"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: endDate)
        if let days = components.day {
            return "Осталось \(days) дней"
        }
        return ""
    }
}

#Preview {
    GymPassView()
}
