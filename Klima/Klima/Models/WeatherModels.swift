//
//  WeatherModels.swift
//  Klima
//

import CoreLocation
import CoreGraphics
import Foundation
import WeatherKit

struct ResolvedLocation {
    let coordinate: CLLocationCoordinate2D
    let name: String
    let bannerMessage: String?
    let timeZone: TimeZone
}

struct HourlyForecast: Identifiable {
    let id: String
    let date: Date?
    let timeLabel: String
    let symbolName: String
    let temperature: Int?
    let precipitationChance: Int?
    let eventLabel: String?
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let dayLabel: String
    let symbolName: String
    let precipitationChance: Int
    let lowTemperature: Int
    let highTemperature: Int
}

struct WeatherDetail: Identifiable {
    let id = UUID()
    let title: String
    let symbolName: String
    let value: String
    let description: String
}

enum RainIntensity {
    case none
    case light
    case medium
    case heavy

    var dropCount: Int {
        switch self {
        case .none: 0
        case .light: 48
        case .medium: 82
        case .heavy: 138
        }
    }

    var speed: Double {
        switch self {
        case .none: 0
        case .light: 0.42
        case .medium: 0.58
        case .heavy: 0.76
        }
    }

    var length: CGFloat {
        switch self {
        case .none: 0
        case .light: 11
        case .medium: 15
        case .heavy: 22
        }
    }

    var opacity: Double {
        switch self {
        case .none: 0
        case .light: 0.11
        case .medium: 0.15
        case .heavy: 0.19
        }
    }

    var splashCount: Int {
        switch self {
        case .none: 0
        case .light: 8
        case .medium: 14
        case .heavy: 22
        }
    }
}

struct WeatherSnapshot {
    enum BuildError: LocalizedError {
        case emptyForecast

        var errorDescription: String? {
            switch self {
            case .emptyForecast:
                return "The weather service did not return forecast data."
            }
        }
    }

    let coordinate: CLLocationCoordinate2D
    let locationName: String
    let timestampLabel: String
    let currentTemperature: Int
    let apparentTemperature: Int
    let highTemperature: Int
    let lowTemperature: Int
    let conditionDescription: String
    let isDaylight: Bool
    let hasThunderstorm: Bool
    let windSpeed: Double
    let windDirectionDegrees: Int
    let currentDate: Date?
    let sunriseDate: Date?
    let sunsetDate: Date?
    let sunriseTimeLabel: String
    let solarNoonTimeLabel: String
    let sunsetTimeLabel: String
    let rainIntensity: RainIntensity
    let hourlyForecast: [HourlyForecast]
    let dailyForecast: [DailyForecast]
    let details: [WeatherDetail]

    init(
        current: CurrentWeather,
        hourly: [HourWeather],
        daily: [DayWeather],
        locationName: String,
        coordinate: CLLocationCoordinate2D,
        timeZone: TimeZone
    ) throws {
        guard let today = daily.first else {
            throw BuildError.emptyForecast
        }

        let formatter = WeatherTimeFormatter(timeZone: timeZone)
        let currentDate = current.date
        let filteredHours = hourly.drop { $0.date < currentDate }
        let first24Hours = Array(filteredHours.prefix(24))
        let nextHourDate = Self.nextHourStart(after: currentDate, timeZone: timeZone)
        let displayHours = Array(hourly.drop { $0.date < nextHourDate }.prefix(23))

        guard !first24Hours.isEmpty else {
            throw BuildError.emptyForecast
        }

        self.coordinate = coordinate
        self.locationName = locationName
        self.timestampLabel = formatter.timestampLabel(currentDate)
        self.currentTemperature = Self.temperatureValue(current.temperature)
        self.apparentTemperature = Self.temperatureValue(current.apparentTemperature)
        self.highTemperature = Self.temperatureValue(today.highTemperature)
        self.lowTemperature = Self.temperatureValue(today.lowTemperature)
        self.conditionDescription = Self.conditionDescription(from: current.condition)
        self.isDaylight = current.isDaylight
        self.hasThunderstorm = Self.hasThunderstorm(symbolName: current.symbolName)
        self.windSpeed = current.wind.speed.converted(to: .milesPerHour).value
        self.windDirectionDegrees = Int(current.wind.direction.converted(to: .degrees).value.rounded())
        self.currentDate = currentDate
        self.sunriseDate = today.sun.sunrise
        self.sunsetDate = today.sun.sunset
        self.sunriseTimeLabel = formatter.shortTimeString(today.sun.sunrise)
        self.solarNoonTimeLabel = formatter.shortTimeString(today.sun.solarNoon)
        self.sunsetTimeLabel = formatter.shortTimeString(today.sun.sunset)
        let activeRainIntensity = Self.strongestRainIntensity(
            Self.rainIntensity(symbolName: current.symbolName),
            Self.rainIntensity(precipitationIntensity: current.precipitationIntensity)
        )
        self.rainIntensity = activeRainIntensity

        #if DEBUG
        print(
            """
            Weather animation debug:
            currentSymbol=\(current.symbolName)
            currentCondition=\(current.condition.description)
            currentPrecipitationIntensity=\(current.precipitationIntensity.converted(to: .kilometersPerHour).value)
            rainIntensity=\(self.rainIntensity)
            """
        )
        #endif

        var hourlyItems = [
            HourlyForecast(
                id: "hour-now",
                date: currentDate,
                timeLabel: "Now",
                symbolName: current.symbolName,
                temperature: Self.temperatureValue(current.temperature),
                precipitationChance: nil,
                eventLabel: nil
            )
        ]

        hourlyItems.append(contentsOf: displayHours.enumerated().map { index, hour in
            HourlyForecast(
                id: "hour-\(index)",
                date: hour.date,
                timeLabel: formatter.hourString(hour.date),
                symbolName: hour.symbolName,
                temperature: Self.temperatureValue(hour.temperature),
                precipitationChance: Self.percentage(hour.precipitationChance),
                eventLabel: nil
            )
        })

        if let sunrise = today.sun.sunrise, Self.isDate(sunrise, from: currentDate, within: displayHours) {
            hourlyItems.append(
                HourlyForecast(
                    id: "sunrise",
                    date: sunrise,
                    timeLabel: formatter.shortTimeString(sunrise),
                    symbolName: "sunrise.fill",
                    temperature: nil,
                    precipitationChance: nil,
                    eventLabel: "Sunrise"
                )
            )
        }

        if let sunset = today.sun.sunset, Self.isDate(sunset, from: currentDate, within: displayHours) {
            hourlyItems.append(
                HourlyForecast(
                    id: "sunset",
                    date: sunset,
                    timeLabel: formatter.shortTimeString(sunset),
                    symbolName: "sunset.fill",
                    temperature: nil,
                    precipitationChance: nil,
                    eventLabel: "Sunset"
                )
            )
        }

        self.hourlyForecast = hourlyItems.sorted {
            ($0.date ?? .distantPast) < ($1.date ?? .distantPast)
        }

        self.dailyForecast = Array(daily.prefix(10)).enumerated().map { index, day in
            DailyForecast(
                dayLabel: formatter.dayLabel(for: day.date, isToday: index == 0),
                symbolName: day.symbolName,
                precipitationChance: Self.percentage(day.precipitationChance) ?? 0,
                lowTemperature: Self.temperatureValue(day.lowTemperature),
                highTemperature: Self.temperatureValue(day.highTemperature)
            )
        }

        let uvIndex = today.uvIndex.value
        let pressure = Int(current.pressure.converted(to: .hectopascals).value.rounded())
        let humidity = Int((current.humidity * 100).rounded())
        let windDirection = Self.cardinalDirection(from: windDirectionDegrees)

        self.details = [
            WeatherDetail(
                title: "UV Index",
                symbolName: "sun.max",
                value: "\(uvIndex)",
                description: Self.uvIndexDescription(Double(uvIndex))
            ),
            WeatherDetail(
                title: "Wind",
                symbolName: "wind",
                value: "\(Int(windSpeed.rounded())) mph",
                description: "\(windDirection) at \(windDirectionDegrees)°."
            ),
            WeatherDetail(
                title: "Humidity",
                symbolName: "humidity",
                value: "\(humidity)%",
                description: "Feels like \(apparentTemperature.temperatureString)."
            ),
            WeatherDetail(
                title: "Pressure",
                symbolName: "gauge.with.dots.needle.50percent",
                value: "\(pressure) hPa",
                description: "Sunrise \(sunriseTimeLabel) • Sunset \(sunsetTimeLabel)."
            )
        ]
    }

    static func temperatureValue(_ measurement: Measurement<UnitTemperature>) -> Int {
        Int(measurement.converted(to: .fahrenheit).value.rounded())
    }

    static func percentage(_ chance: Double) -> Int? {
        guard chance > 0 else { return nil }
        return Int((chance * 100).rounded())
    }

    static func rainIntensity(symbolName: String) -> RainIntensity {
        switch symbolName {
        case let name where name.contains("bolt"):
            return .heavy
        case let name where name.contains("heavyrain"):
            return .heavy
        case let name where name.contains("rain") || name.contains("sleet"):
            return .medium
        case let name where name.contains("drizzle"):
            return .light
        default:
            return .none
        }
    }

    static func rainIntensity(precipitationIntensity: Measurement<UnitSpeed>) -> RainIntensity {
        let millimetersPerHour = precipitationIntensity.converted(to: .kilometersPerHour).value * 1_000_000
        switch millimetersPerHour {
        case 7...:
            return .heavy
        case 2..<7:
            return .medium
        case 0.05..<2:
            return .light
        default:
            return .none
        }
    }

    static func strongestRainIntensity(_ first: RainIntensity, _ second: RainIntensity) -> RainIntensity {
        rank(first) >= rank(second) ? first : second
    }

    private static func rank(_ intensity: RainIntensity) -> Int {
        switch intensity {
        case .none: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }

    static func hasThunderstorm(symbolName: String) -> Bool {
        symbolName.contains("bolt")
    }

    private static func conditionDescription(from condition: WeatherKit.WeatherCondition) -> String {
        condition.description
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private static func isDate(_ date: Date, within hourly: [HourWeather]) -> Bool {
        guard let start = hourly.first?.date, let end = hourly.last?.date else { return false }
        return date >= start && date <= end
    }

    private static func isDate(_ date: Date, from start: Date, within hourly: [HourWeather]) -> Bool {
        guard let end = hourly.last?.date else { return false }
        return date >= start && date <= end
    }

    private static func nextHourStart(after date: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfCurrentHour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: startOfCurrentHour) ?? date
    }

    private static func uvIndexDescription(_ value: Double) -> String {
        switch value {
        case 0..<3:
            return "Low risk through most of the day."
        case 3..<6:
            return "Moderate exposure around midday."
        case 6..<8:
            return "High intensity near peak sun."
        case 8..<11:
            return "Very high UV levels today."
        default:
            return "Extreme UV. Limit sun exposure."
        }
    }

    private static func cardinalDirection(from degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let normalized = Double((degrees % 360 + 360) % 360)
        let index = Int((normalized / 45.0).rounded())
        return directions[index]
    }
}

private struct WeatherTimeFormatter {
    private let timestampFormatter: DateFormatter
    private let hourFormatter: DateFormatter
    private let shortTimeFormatter: DateFormatter
    private let weekdayFormatter: DateFormatter

    init(timeZone: TimeZone) {
        timestampFormatter = DateFormatter()
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        timestampFormatter.timeZone = timeZone
        timestampFormatter.dateFormat = "EEEE, h:mm"

        hourFormatter = DateFormatter()
        hourFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourFormatter.timeZone = timeZone
        hourFormatter.dateFormat = "ha"

        shortTimeFormatter = DateFormatter()
        shortTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        shortTimeFormatter.timeZone = timeZone
        shortTimeFormatter.dateFormat = "h:mm a"

        weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.dateFormat = "EEEE"
    }

    func timestampLabel(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    func hourString(_ date: Date?) -> String {
        guard let date else { return "--" }
        return hourFormatter.string(from: date)
    }

    func shortTimeString(_ date: Date?) -> String {
        guard let date else { return "--" }
        return shortTimeFormatter.string(from: date)
    }

    func dayLabel(for date: Date, isToday: Bool) -> String {
        isToday ? "Today" : weekdayFormatter.string(from: date)
    }
}
