import SwiftUI
import MapKit

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskViewModel.self) private var viewModel

    var taskToEdit: ShowUpTask? = nil
    var onSave: ((ShowUpTask) -> Void)? = nil

    @State private var taskName = ""
    @State private var searchText = ""
    @State private var selectedLocation: MKMapItem?
    @State private var selectedDuration: TimeInterval = 1800 // 30 min
    @State private var selectedColorHex = TaskViewModel.pastelColors[0]
    @State private var scheduledDays: Set<Int> = Set(1...7)
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    // Holds the existing coordinate when editing (before any new location is searched)
    @State private var existingCoordinate: CLLocationCoordinate2D?
    @State private var existingLocationName: String = ""

    private var isEditing: Bool { taskToEdit != nil }

    private let durations: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("60 min", 3600),
        ("90 min", 5400)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Task name
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Task Name", systemImage: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            TextField("e.g. Morning Gym", text: $taskName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Location search
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Location", systemImage: "mappin.and.ellipse")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white.opacity(0.4))
                                TextField("Search for a place", text: $searchText)
                                    .foregroundColor(.white)
                                    .onSubmit { performSearch() }
                                if isSearching {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Search results
                            if !searchResults.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(searchResults, id: \.self) { item in
                                        Button {
                                            selectLocation(item)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.name ?? "Unknown")
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.white)
                                                    Text(item.placemark.title ?? "")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.5))
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.3))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                        }
                                        if item != searchResults.last {
                                            Divider().background(Color.white.opacity(0.1))
                                        }
                                    }
                                }
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Map preview
                            if let location = selectedLocation {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.red)
                                        Text(location.name ?? "Selected Location")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }

                                    Map(position: $mapPosition) {
                                        Annotation(location.name ?? "", coordinate: location.placemark.coordinate) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.red.opacity(0.2))
                                                    .frame(width: 120, height: 120)
                                                Circle()
                                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                                    .frame(width: 120, height: 120)
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .disabled(true)
                                }
                            } else if let coord = existingCoordinate {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.red)
                                        Text(existingLocationName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                    }

                                    Map(position: $mapPosition) {
                                        Annotation(existingLocationName, coordinate: coord) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.red.opacity(0.2))
                                                    .frame(width: 120, height: 120)
                                                Circle()
                                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                                    .frame(width: 120, height: 120)
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .disabled(true)
                                }
                            }
                        }

                        // Duration picker
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Duration", systemImage: "timer")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            HStack(spacing: 10) {
                                ForEach(durations, id: \.1) { label, value in
                                    Button {
                                        selectedDuration = value
                                    } label: {
                                        Text(label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedDuration == value ? .black : .white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(selectedDuration == value ? Color.white : Color.white.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Schedule picker
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Schedule", systemImage: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                Spacer()
                                Button {
                                    scheduledDays = Set(1...7)
                                } label: {
                                    Text("Every Day")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(scheduledDays.count == 7 ? .black : .white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(scheduledDays.count == 7 ? Color.white : Color.white.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }

                            // Mon-first order: [2,3,4,5,6,7,1], labels M T W T F S S
                            let dayOrder = [2, 3, 4, 5, 6, 7, 1]
                            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
                            HStack(spacing: 0) {
                                ForEach(Array(dayOrder.enumerated()), id: \.offset) { index, weekday in
                                    let isSelected = scheduledDays.contains(weekday)
                                    Button {
                                        if isSelected && scheduledDays.count > 1 {
                                            scheduledDays.remove(weekday)
                                        } else if !isSelected {
                                            scheduledDays.insert(weekday)
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text(dayLabels[index])
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(isSelected ? .white : .white.opacity(0.3))
                                            Circle()
                                                .fill(isSelected ? Color.white : Color.clear)
                                                .overlay(
                                                    Circle().stroke(Color.white.opacity(isSelected ? 0 : 0.25), lineWidth: 1.5)
                                                )
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Card Color", systemImage: "paintpalette")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(TaskViewModel.pastelColors, id: \.self) { hex in
                                    Button {
                                        selectedColorHex = hex
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: hex) ?? .white)
                                                .frame(width: 44, height: 44)
                                            if selectedColorHex == hex {
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 3)
                                                    .frame(width: 50, height: 50)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Preview card
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Preview", systemImage: "eye")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: selectedColorHex) ?? .white)
                                    .frame(height: 120)
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("⚡ 0")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.black.opacity(0.7))
                                        Spacer()
                                        Text(taskName.isEmpty ? "Task Name" : taskName)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.black)
                                        Text(selectedLocation?.name ?? "Location")
                                            .font(.system(size: 12))
                                            .foregroundColor(.black.opacity(0.55))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        ProgressRingView(progress: 0, isCompleted: false)
                                            .frame(width: 44, height: 44)
                                        Spacer()
                                        Text(durations.first(where: { $0.1 == selectedDuration })?.0 ?? "")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.black.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .frame(height: 120)
                            }
                        }

                        // Save button
                        Button {
                            saveTask()
                        } label: {
                            Text("Save Task")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSave ? Color.white : Color.white.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                guard let task = taskToEdit else { return }
                taskName = task.name
                searchText = task.locationName
                selectedDuration = task.requiredDuration
                selectedColorHex = task.colorHex
                scheduledDays = Set(task.scheduledDays)
                existingCoordinate = task.coordinate
                existingLocationName = task.locationName
                mapPosition = .region(MKCoordinateRegion(
                    center: task.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        }
    }

    private var canSave: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (selectedLocation != nil || existingCoordinate != nil)
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        MKLocalSearch(request: request).start { response, _ in
            isSearching = false
            searchResults = response?.mapItems ?? []
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        searchResults = []
        searchText = item.name ?? ""
        if let coord = item.placemark.location?.coordinate {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    private func saveTask() {
        if let task = taskToEdit {
            task.name = taskName.trimmingCharacters(in: .whitespaces)
            task.requiredDuration = selectedDuration
            task.colorHex = selectedColorHex
            task.scheduledDays = Array(scheduledDays)
            if let location = selectedLocation,
               let coord = location.placemark.location?.coordinate {
                task.locationName = location.name ?? searchText
                task.latitude = coord.latitude
                task.longitude = coord.longitude
            }
            viewModel.updateTask(task)
            dismiss()
        } else {
            guard let location = selectedLocation,
                  let coord = location.placemark.location?.coordinate else { return }
            let task = ShowUpTask(
                name: taskName.trimmingCharacters(in: .whitespaces),
                locationName: location.name ?? searchText,
                latitude: coord.latitude,
                longitude: coord.longitude,
                requiredDuration: selectedDuration,
                colorHex: selectedColorHex,
                scheduledDays: Array(scheduledDays)
            )
            onSave?(task)
            dismiss()
        }
    }
}
