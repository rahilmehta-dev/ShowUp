import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "house.fill")
                }
                .tag(0)

            MapOverviewView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
