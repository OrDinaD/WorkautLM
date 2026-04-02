import SwiftUI
import SwiftData

struct MainTabView: View {
    init() {
        // Настройка внешнего вида TabBar для темной темы
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Тренировки", systemImage: "dumbbell.fill")
                }
            
            OffDaysView()
                .tabItem {
                    Label("Отдых", systemImage: "bed.double.fill")
                }
            
            GymPassView()
                .tabItem {
                    Label("Инфо", systemImage: "info.circle.fill")
                }
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
