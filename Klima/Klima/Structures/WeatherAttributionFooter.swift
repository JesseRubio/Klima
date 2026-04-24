//
//  WeatherAttributionFooter.swift
//  Klima
//

import SwiftUI

struct WeatherAttributionFooter: View {
    let isDaylight: Bool
    @State private var attribution: WeatherKitAttributionInfo?

    private var markURL: URL {
        guard let attribution else { return URL(string: "about:blank")! }
        return isDaylight ? attribution.combinedMarkLightURL : attribution.combinedMarkDarkURL
    }

    private var primaryTextColor: Color {
        isDaylight ? .klimaTextDayPrimary.opacity(0.68) : .white.opacity(0.72)
    }

    private var secondaryTextColor: Color {
        isDaylight ? .klimaTextDaySecondary.opacity(0.76) : .white.opacity(0.42)
    }

    var body: some View {
        VStack(spacing: 10) {
            if let attribution {
                AsyncImage(url: markURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Text(attribution.serviceName)
                        .font(.custom(CityListFontStyle.medium.rawValue, size: 12))
                        .foregroundStyle(primaryTextColor)
                }
                .frame(height: 18)
                .frame(maxWidth: .infinity)

                Link(destination: attribution.legalPageURL) {
                    Text("Weather data attribution")
                        .font(.custom(CityListFontStyle.book.rawValue, size: 12))
                        .foregroundStyle(secondaryTextColor)
                        .underline()
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Loading weather data attribution…")
                    .font(.custom(CityListFontStyle.book.rawValue, size: 12))
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .task {
            guard attribution == nil else { return }
            attribution = try? await KlimaWeatherService.fetchAttribution()
        }
    }
}
