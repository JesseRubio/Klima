//
//  StoredCity.swift
//  Klima
//

import Foundation

struct StoredCity: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let region: String
    let country: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String?

    var locationDetail: String {
        [region, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    func matches(_ other: StoredCity) -> Bool {
        abs(latitude - other.latitude) < 0.0001 && abs(longitude - other.longitude) < 0.0001
    }
}

struct SavedCityWeather: Identifiable {
    let id: UUID
    let storedCity: StoredCity
    let name: String
    let timestamp: String
    let condition: String
    let temperature: Int
    let highTemperature: Int
    let lowTemperature: Int
    let isDaylight: Bool
    let rainIntensity: RainIntensity

    var detailLine: String {
        let locationParts = [storedCity.region, storedCity.country].filter { !$0.isEmpty }.joined(separator: ", ")
        guard !locationParts.isEmpty else { return timestamp }
        return "\(locationParts)  •  \(timestamp)"
    }
}
