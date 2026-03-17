import SwiftUI
import SwiftData
import ARKit
import SceneKit
import AVFoundation

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Тренировки", systemImage: "figure.run")
                }
            
            FaceProgressView()
                .tabItem {
                    Label("Лицо", systemImage: "faceid")
                }
        }
        .tint(.purple)
    }
}

struct FaceProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FaceLog.timestamp, order: .reverse) private var faceLogs: [FaceLog]
    @State private var showingCamera = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if faceLogs.isEmpty {
                    ContentUnavailableView {
                        Label("Нет данных о лице", systemImage: "camera.viewfinder")
                            .foregroundStyle(.purple)
                    } description: {
                        Text("Начните делать ежедневные селфи, чтобы видеть динамику похудения лица.")
                            .foregroundStyle(.gray)
                    }
                } else {
                    List {
                        ForEach(faceLogs) { log in
                            FaceLogCard(log: log)
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteLog(log)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                }
            }
            .navigationTitle("Динамика лица")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCamera = true }) {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                FaceCameraView()
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
    }
    
    private func deleteLog(_ log: FaceLog) {
        // Удаляем файл изображения
        if let path = log.imagePath {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(log)
    }
}

struct FaceLogCard: View {
    let log: FaceLog
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 70, height: 90)
                
                if let path = log.imagePath, let image = loadFromDocuments(path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack {
                    Image(systemName: log.isMorning ? "sun.max.fill" : "moon.fill")
                    Text(log.isMorning ? "Утро" : "Вечер")
                }
                .font(.caption)
                .foregroundStyle(.purple)
                
                if let width = log.faceWidth {
                    Text("Ширина: \(width * 100, specifier: "%.1f") см")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func loadFromDocuments(_ filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}

// MARK: - ARKit Face Camera
struct FaceCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var arView = ARFaceViewContainer()
    @State private var cameraAuthorized = false
    
    var body: some View {
        ZStack {
            if cameraAuthorized {
                arView.ignoresSafeArea()
                
                // Овал-ориентир
                Ellipse()
                    .stroke(lineWidth: 3)
                    .foregroundStyle(.purple.opacity(0.5))
                    .frame(width: 250, height: 350)
                    .overlay(
                        Text("Поместите лицо в овал")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .offset(y: 190)
                    )
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.purple)
                    Text("Нужен доступ к камере").foregroundStyle(.white)
                    Button("Разрешить") { checkCameraPermission() }
                        .buttonStyle(.borderedProminent).tint(.purple)
                    Button("Отмена") { dismiss() }.foregroundStyle(.gray)
                }
            }
            
            // UI Overlay
            if cameraAuthorized {
                VStack {
                    HStack {
                        Button("Отмена") { dismiss() }
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                        Spacer()
                        if arView.view.currentFaceWidth > 0 {
                            Text("\(arView.view.currentFaceWidth * 100, specifier: "%.1f") см")
                                .font(.system(.title3, design: .monospaced)).bold()
                                .foregroundStyle(.white).padding()
                                .background(Color.purple.opacity(0.8)).clipShape(Capsule())
                        }
                    }.padding()
                    Spacer()
                    Button(action: takePhoto) {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 70, height: 70)
                            Circle().stroke(Color.purple, lineWidth: 3).frame(width: 80, height: 80)
                        }
                    }.padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            initialCheck()
        }
    }
    
    private func initialCheck() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            cameraAuthorized = true
        }
    }
    
    private func checkCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { self.cameraAuthorized = granted }
        }
    }
    
    private func takePhoto() {
        let snapshot = arView.view.snapshot()
        let width = arView.view.currentFaceWidth
        let filename = "face_\(Date().timeIntervalSince1970).jpg"
        saveImage(snapshot, filename: filename)
        let hour = Calendar.current.component(.hour, from: Date())
        let newLog = FaceLog(timestamp: Date(), imagePath: filename, faceWidth: width, isMorning: hour < 12)
        modelContext.insert(newLog)
        dismiss()
    }
    
    private func saveImage(_ image: UIImage, filename: String) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            try? data.write(to: url)
        }
    }
}

struct ARFaceViewContainer: UIViewRepresentable {
    let view = ARFaceSCNView()
    func makeUIView(context: Context) -> ARFaceSCNView {
        view.setup()
        return view
    }
    func updateUIView(_ uiView: ARFaceSCNView, context: Context) {}
}

class ARFaceSCNView: ARSCNView, ARSCNViewDelegate {
    var currentFaceWidth: Double = 0
    private var faceMeshNode: SCNNode?
    
    func setup() {
        self.delegate = self
        let config = ARFaceTrackingConfiguration()
        self.session.run(config)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = self.device, let faceAnchor = anchor as? ARFaceAnchor else { return nil }
        
        // Создаем геометрию лица (сетку)
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        
        // Настраиваем материал сетки, чтобы она была видна, но не перекрывала лицо совсем
        node.geometry?.firstMaterial?.fillMode = .lines
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.purple.withAlphaComponent(0.5)
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
        
        // Обновляем сетку под текущую мимику
        faceGeometry.update(from: faceAnchor.geometry)
        
        // Расчет ширины лица
        let vertices = faceAnchor.geometry.vertices
        let leftIdx = 450 
        let rightIdx = 16 
        
        if vertices.count > max(leftIdx, rightIdx) {
            let left = vertices[leftIdx]
            let right = vertices[rightIdx]
            let dist = sqrt(pow(left.x - right.x, 2) + pow(left.y - right.y, 2) + pow(left.z - right.z, 2))
            
            DispatchQueue.main.async {
                self.currentFaceWidth = Double(dist)
            }
        }
    }
}
