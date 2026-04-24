//
//  WeatherViewModel.swift
//  Klima
//

import CoreLocation
import Combine
import Foundation
import WeatherKit

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var currentLocationSnapshot: WeatherSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var bannerMessage: String?

    private let locationClient = LocationClient()
    private let weatherService = KlimaWeatherService()
    private var hasLoaded = false
    private let selectedCityDefaultsKey = "selected_default_city"
    private var selectedLocation: SelectedLocation

    private enum SelectedLocation {
        case current
        case city(StoredCity)
    }

    init() {
        if
            let data = UserDefaults.standard.data(forKey: selectedCityDefaultsKey),
            let storedCity = try? JSONDecoder().decode(StoredCity.self, from: data)
        {
            selectedLocation = .city(storedCity)
        } else {
            selectedLocation = .current
        }
    }

    func loadWeatherIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refreshWeather()
    }

    func refreshWeather() async {
        isLoading = true
        errorMessage = nil
        bannerMessage = nil

        do {
            let resolvedLocation = await resolveLocation()
            let currentSnapshot = try await weatherService.fetchWeather(
                latitude: resolvedLocation.coordinate.latitude,
                longitude: resolvedLocation.coordinate.longitude,
                locationName: resolvedLocation.name,
                coordinate: resolvedLocation.coordinate,
                timeZone: resolvedLocation.timeZone
            )
            currentLocationSnapshot = currentSnapshot

            switch selectedLocation {
            case .current:
                snapshot = currentSnapshot
                bannerMessage = resolvedLocation.bannerMessage
            case .city(let city):
                snapshot = try await weatherService.fetchWeather(
                    latitude: city.latitude,
                    longitude: city.longitude,
                    locationName: city.locationDetail.isEmpty ? city.name : "\(city.name), \(city.locationDetail)",
                    coordinate: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
                    timeZone: TimeZone(identifier: city.timeZoneIdentifier ?? "") ?? .autoupdatingCurrent
                )
            }
        } catch {
            #if DEBUG
            print("Weather load failed:", error)
            #endif
            errorMessage = userFacingMessage(for: error)
        }

        isLoading = false
    }

    func showCurrentLocation() async {
        selectedLocation = .current
        UserDefaults.standard.removeObject(forKey: selectedCityDefaultsKey)
        if let currentLocationSnapshot {
            snapshot = currentLocationSnapshot
            bannerMessage = nil
        } else {
            await refreshWeather()
        }
    }

    func showCity(_ city: StoredCity) async {
        selectedLocation = .city(city)
        if let data = try? JSONEncoder().encode(city) {
            UserDefaults.standard.set(data, forKey: selectedCityDefaultsKey)
        }
        await refreshWeather()
    }

    private func resolveLocation() async -> ResolvedLocation {
        do {
            let location = try await locationClient.requestCurrentLocation()
            let geocodeResult = await locationClient.reverseGeocode(location)
            return ResolvedLocation(
                coordinate: location.coordinate,
                name: geocodeResult.name ?? "Current Location",
                bannerMessage: nil,
                timeZone: geocodeResult.timeZone ?? .autoupdatingCurrent
            )
        } catch {
            return ResolvedLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.3230, longitude: -122.0322),
                name: "Cupertino",
                bannerMessage: "Showing Cupertino until location access is available.",
                timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .autoupdatingCurrent
            )
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let weatherError = error as? KlimaWeatherService.WeatherError {
            return weatherError.localizedDescription
        }

        if let snapshotError = error as? WeatherSnapshot.BuildError {
            return snapshotError.localizedDescription
        }

        if let weatherKitError = error as? WeatherKit.WeatherError {
            switch weatherKitError {
            case .permissionDenied:
                return "WeatherKit permission was denied. Check the app's signing, WeatherKit capability, and provisioning, then try again."
            case .unknown:
                break
            @unknown default:
                break
            }

            let parts = [
                weatherKitError.errorDescription,
                weatherKitError.failureReason,
                weatherKitError.recoverySuggestion
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

            if !parts.isEmpty {
                return parts.joined(separator: " ")
            }
        }

        let genericError = error as NSError
        let description = genericError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty, description != "The operation couldn’t be completed." {
            return description
        }

        var parts: [String] = []

        let domainAndCode = "\(genericError.domain) (\(genericError.code))"
        parts.append("Weather request failed: \(domainAndCode).")

        if
            let underlyingError = genericError.userInfo[NSUnderlyingErrorKey] as? NSError,
            !underlyingError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            parts.append("Underlying error: \(underlyingError.domain) (\(underlyingError.code)) - \(underlyingError.localizedDescription)")
        }

        if
            let failureReason = genericError.localizedFailureReason?.trimmingCharacters(in: .whitespacesAndNewlines),
            !failureReason.isEmpty
        {
            parts.append(failureReason)
        }

        if
            let recoverySuggestion = genericError.localizedRecoverySuggestion?.trimmingCharacters(in: .whitespacesAndNewlines),
            !recoverySuggestion.isEmpty
        {
            parts.append(recoverySuggestion)
        }

        return parts.joined(separator: " ")
    }
}
