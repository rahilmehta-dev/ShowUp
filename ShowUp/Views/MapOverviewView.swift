import SwiftUI
import MapKit

struct MapOverviewView: View {
    @Environment(TaskViewModel.self) private var viewModel
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Map(position: $mapPosition) {
                    // User location
                    UserAnnotation()

                    // Task geofences
                    ForEach(viewModel.tasks, id: \.id) { task in
                        let isActive = viewModel.activeTaskIDs.contains(task.id)
                        let color = task.cardColor

                        Annotation(task.name, coordinate: task.coordinate) {
                            ZStack {
                                // Geofence circle indicator
                                Circle()
                                    .fill(color.opacity(isActive ? 0.3 : 0.15))
                                    .frame(width: 80, height: 80)
                                Circle()
                                    .stroke(color.opacity(isActive ? 0.8 : 0.4), lineWidth: isActive ? 2 : 1)
                                    .frame(width: 80, height: 80)
                                VStack(spacing: 2) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(color)
                                    Text(task.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onAppear {
                    if !viewModel.tasks.isEmpty {
                        fitMapToTasks()
                    }
                }

                // Legend overlay
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        LegendItem(color: .orange, label: "Active")
                        LegendItem(color: .white.opacity(0.4), label: "Waiting")
                        LegendItem(color: .green, label: "Done")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func fitMapToTasks() {
        guard !viewModel.tasks.isEmpty else { return }
        if viewModel.tasks.count == 1 {
            let task = viewModel.tasks[0]
            mapPosition = .region(MKCoordinateRegion(
                center: task.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
            return
        }
        let lats = viewModel.tasks.map { $0.latitude }
        let lons = viewModel.tasks.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.02)
        )
        mapPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
