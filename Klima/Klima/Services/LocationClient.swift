//
//  LocationClient.swift
//  Klima
//

import CoreLocation
import MapKit

final class LocationClient: NSObject, CLLocationManagerDelegate {
    struct ReverseGeocodeResult {
        let name: String?
        let timeZone: TimeZone?
    }

    enum LocationError: LocalizedError {
        case denied
        case restricted
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Location access was denied."
            case .restricted:
                return "Location access is restricted on this device."
            case .unavailable:
                return "Current location is unavailable."
            }
        }
    }

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    @MainActor
    func requestCurrentLocation() async throws -> CLLocation {
        try await ensureAuthorized()

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func reverseGeocode(_ location: CLLocation) async -> ReverseGeocodeResult {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return ReverseGeocodeResult(name: nil, timeZone: nil)
        }

        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else {
                return ReverseGeocodeResult(name: nil, timeZone: nil)
            }

            let name: String?
            if let compactLocation = compactLocationLabel(from: mapItem.address?.fullAddress) {
                name = compactLocation
            } else if let compactLocation = compactLocationLabel(from: mapItem.address?.shortAddress) {
                name = compactLocation
            } else if let itemName = mapItem.name, !itemName.isEmpty {
                name = itemName
            } else {
                name = mapItem.address?.fullAddress
            }

            return ReverseGeocodeResult(name: name, timeZone: mapItem.timeZone)
        } catch {
            return ReverseGeocodeResult(name: nil, timeZone: nil)
        }
    }

    private func compactLocationLabel(from address: String?) -> String? {
        guard let address, !address.isEmpty else { return nil }

        let components = address
            .replacingOccurrences(of: "\n", with: ", ")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !components.isEmpty else { return nil }

        if components.count >= 3 {
            let city = components[components.count - 3]
            let stateToken = components[components.count - 2]
                .split(separator: " ")
                .first
                .map(String.init) ?? components[components.count - 2]
            return "\(city), \(stateToken)"
        }

        if components.count >= 2 {
            return components.suffix(2).joined(separator: ", ")
        }

        return components.first
    }

    @MainActor
    private func ensureAuthorized() async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .denied:
            throw LocationError.denied
        case .restricted:
            throw LocationError.restricted
        @unknown default:
            throw LocationError.unavailable
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            continuation.resume()
        case .denied:
            continuation.resume(throwing: LocationError.denied)
        case .restricted:
            continuation.resume(throwing: LocationError.restricted)
        case .notDetermined:
            authorizationContinuation = continuation
        @unknown default:
            continuation.resume(throwing: LocationError.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil

        if let location = locations.first {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: LocationError.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }
}
