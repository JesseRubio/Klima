//
//  WeatherKitService.swift
//  Klima
//

import CoreLocation
import Foundation
import WeatherKit

struct WeatherKitAttributionInfo {
    let combinedMarkDarkURL: URL
    let combinedMarkLightURL: URL
    let legalPageURL: URL
    let serviceName: String
}

struct KlimaWeatherService {
    enum WeatherError: LocalizedError {
        case emptyForecast

        var errorDescription: String? {
            switch self {
            case .emptyForecast:
                return "The weather service did not return forecast data."
            }
        }
    }

    private let service = WeatherService.shared

    static func fetchAttribution() async throws -> WeatherKitAttributionInfo {
        let attribution = try await WeatherService.shared.attribution
        return WeatherKitAttributionInfo(
            combinedMarkDarkURL: attribution.combinedMarkDarkURL,
            combinedMarkLightURL: attribution.combinedMarkLightURL,
            legalPageURL: attribution.legalPageURL,
            serviceName: attribution.serviceName
        )
    }

    func fetchWeather(
        latitude: Double,
        longitude: Double,
        locationName: String,
        coordinate: CLLocationCoordinate2D,
        timeZone: TimeZone
    ) async throws -> WeatherSnapshot {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let (current, hourly, daily) = try await service.weather(
            for: location,
            including: .current,
            .hourly,
            .daily
        )

        return try WeatherSnapshot(
            current: current,
            hourly: Array(hourly),
            daily: Array(daily),
            locationName: locationName,
            coordinate: coordinate,
            timeZone: timeZone
        )
    }

    func fetchSavedCityWeather(city: StoredCity) async throws -> SavedCityWeather {
        let timeZone = TimeZone(identifier: city.timeZoneIdentifier ?? "") ?? .autoupdatingCurrent
        let location = CLLocation(latitude: city.latitude, longitude: city.longitude)
        let (current, daily) = try await service.weather(
            for: location,
            including: .current,
            .daily
        )

        guard let today = Array(daily).first else {
            throw WeatherError.emptyForecast
        }

        return SavedCityWeather(
            id: city.id,
            storedCity: city,
            name: city.name,
            timestamp: CityListTimeFormatter(timeZone: timeZone).timeString(from: current.date),
            condition: current.condition.description
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.capitalized }
                .joined(separator: " "),
            temperature: WeatherSnapshot.temperatureValue(current.temperature),
            highTemperature: WeatherSnapshot.temperatureValue(today.highTemperature),
            lowTemperature: WeatherSnapshot.temperatureValue(today.lowTemperature),
            isDaylight: current.isDaylight,
            rainIntensity: WeatherSnapshot.rainIntensity(symbolName: current.symbolName)
        )
    }
}

private struct CityListTimeFormatter {
    private let formatter: DateFormatter

    init(timeZone: TimeZone) {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
    }

    func timeString(from date: Date) -> String {
        formatter.string(from: date)
    }
}
