import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var store: WatchStore

    private var todaysTasks: [WatchTask] { store.tasks }

    var body: some View {
        if todaysTasks.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No tasks today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else {
            List(todaysTasks) { task in
                NavigationLink(destination: WatchTaskDetailView(task: task)) {
                    WatchTaskRowView(task: task)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            .listStyle(.plain)
            .navigationTitle("ShowUp")
        }
    }
}
