import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isSharing = false
    @Published var placeName: String?
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()
    private var wantsLocation = false
    private var lastGeocoded: CLLocation?
    private var geocodeTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func toggle() {
        if isSharing {
            stop()
            return
        }
        wantsLocation = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            start()
        default:
            authorizationDenied = true
        }
    }

    func stop() {
        wantsLocation = false
        isSharing = false
        geocodeTask?.cancel()
        manager.stopUpdatingLocation()
        placeName = nil
        latitude = nil
        longitude = nil
        lastGeocoded = nil
    }

    private func start() {
        authorizationDenied = false
        isSharing = true
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                authorizationDenied = false
                if wantsLocation { start() }
            case .denied, .restricted:
                authorizationDenied = true
                isSharing = false
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            reverseGeocode(location)
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        if let lastGeocoded, location.distance(from: lastGeocoded) < 40 { return }
        lastGeocoded = location
        geocodeTask?.cancel()
        geocodeTask = Task {
            // CLGeocoder rather than MKReverseGeocodingRequest: the MapKit
            // request type is iOS 26+, and this app ships to iOS 18.
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            guard !Task.isCancelled else { return }
            let placemark = placemarks?.first
            placeName = placemark?.areasOfInterest?.first
                ?? placemark?.locality
                ?? placemark?.name
        }
    }
}
