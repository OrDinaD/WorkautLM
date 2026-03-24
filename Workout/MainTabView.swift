import SwiftUI
import SwiftData

struct MainTabView: View {
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
        }
        .tint(.purple)
    }
}

#Preview {
    MainTabView()
}
