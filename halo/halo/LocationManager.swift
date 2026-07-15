//
//  LocationManager.swift
//  halo
//
//  App target only. One-shot CoreLocation (coarse accuracy is plenty for astronomy),
//  reverse-geocoded to a place name, cached so the widget can read it on paid builds.
//

import SwiftUI
import CoreLocation
import WidgetKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    enum Status { case unknown, denied, authorized }

    var status: Status = .unknown
    var snapshot: LocationSnapshot?          // resolved coordinate + name (nil until first fix)

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        snapshot = LocationCache.load()      // seed from cache for an instant first paint
        apply(status: manager.authorizationStatus)
    }

    /// Ask for permission if undetermined, else grab a fresh fix.
    func requestOrRefresh() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func refresh() {
        let s = manager.authorizationStatus
        if s == .authorizedWhenInUse || s == .authorizedAlways { manager.requestLocation() }
    }

    private func apply(status s: CLAuthorizationStatus) {
        switch s {
        case .authorizedWhenInUse, .authorizedAlways: status = .authorized
        case .denied, .restricted: status = .denied
        default: status = .unknown
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        apply(status: manager.authorizationStatus)
        if status == .authorized { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        store(LocationSnapshot(latitude: lat, longitude: lon, name: snapshot?.name ?? "Current location", savedAt: Date()))
        geocoder.reverseGeocodeLocation(loc) { [weak self] places, _ in
            guard let self, let p = places?.first else { return }
            let name = p.locality ?? p.administrativeArea ?? p.country ?? "Current location"
            self.store(LocationSnapshot(latitude: lat, longitude: lon, name: name, savedAt: Date()))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last good snapshot; a failed fix shouldn't blank the UI.
    }

    private func store(_ snap: LocationSnapshot) {
        snapshot = snap
        LocationCache.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
