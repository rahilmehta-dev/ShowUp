import Foundation
import CoreLocation
import SwiftData
import SwiftUI
import Combine

@Observable
final class LocationManager: NSObject {
    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?

    // Callbacks
    var onEnterRegion: ((String) -> Void)?
    var onExitRegion: ((String) -> Void)?

    var monitoredRegionIDs: Set<String> = []
    private var gracePeriodTimers: [String: Timer] = [:]
    var gracePeriodEnabled: Bool = true
    let gracePeriodDuration: TimeInterval = 300 // 5 minutes

    override init() {
        super.init()
        manager.delegate = self
        // Geofencing doesn't need GPS precision — hundred-meter accuracy saves significant battery
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true  // let iOS pause when user is stationary
        manager.showsBackgroundLocationIndicator = true
        authorizationStatus = manager.authorizationStatus
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    /// One-shot fix so iOS can evaluate geofence states. Stops automatically after one result.
    func requestOneTimeFix() {
        manager.requestLocation()
    }

    func startMonitoringTask(_ task: ShowUpTask) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(
            center: task.coordinate,
            radius: task.radius,
            identifier: task.regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        monitoredRegionIDs.insert(task.regionIdentifier)
    }

    func stopMonitoringTask(_ task: ShowUpTask) {
        for region in manager.monitoredRegions where region.identifier == task.regionIdentifier {
            manager.stopMonitoring(for: region)
        }
        monitoredRegionIDs.remove(task.regionIdentifier)
    }

    func stopMonitoringAll() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        monitoredRegionIDs.removeAll()
    }

    func requestStateForAllRegions() {
        for region in manager.monitoredRegions {
            manager.requestState(for: region)
        }
    }

    func startLocationUpdates() {
        manager.startUpdatingLocation()
    }

    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            // Single-shot fix so iOS can immediately evaluate all geofence states.
            // requestLocation() fires once then stops — no continuous GPS drain.
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        // Cancel any grace period timer for this region
        gracePeriodTimers[circularRegion.identifier]?.invalidate()
        gracePeriodTimers.removeValue(forKey: circularRegion.identifier)

        onEnterRegion?(circularRegion.identifier)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        if gracePeriodEnabled {
            // Start a grace period timer before pausing
            let timer = Timer.scheduledTimer(withTimeInterval: gracePeriodDuration, repeats: false) { [weak self] _ in
                self?.gracePeriodTimers.removeValue(forKey: circularRegion.identifier)
                self?.onExitRegion?(circularRegion.identifier)
            }
            gracePeriodTimers[circularRegion.identifier] = timer
        } else {
            onExitRegion?(circularRegion.identifier)
        }
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        switch state {
        case .inside:
            onEnterRegion?(circularRegion.identifier)
        case .outside:
            break
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Required by requestLocation() — ignore kCLErrorLocationUnknown (transient, iOS retries)
        let clError = error as? CLError
        if clError?.code != .locationUnknown {
            print("Location error: \(error)")
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence monitoring failed for \(region?.identifier ?? "unknown"): \(error)")
    }
}

// MARK: - Coordinate Extension
extension ShowUpTask {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
