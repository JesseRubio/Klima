//
//  ContentView.swift
//  Klima
//
//  Created by Jesse Rubio on 4/19/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var selectedHourlyID: String?
    @State private var isShowingCityList = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ZStack {
                AppBackdrop(theme: SkyTheme(snapshot: viewModel.snapshot, now: context.date))

                if let snapshot = viewModel.snapshot, snapshot.rainIntensity != .none {
                    MistOverlay(intensity: snapshot.rainIntensity, isDaylight: snapshot.isDaylight)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)

                    StormCloudCeilingOverlay(
                        intensity: snapshot.rainIntensity,
                        windDirectionDegrees: snapshot.windDirectionDegrees,
                        windSpeed: snapshot.windSpeed,
                        isDaylight: snapshot.isDaylight
                    )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)

                    RainOverlay(
                        intensity: snapshot.rainIntensity,
                        windDirectionDegrees: snapshot.windDirectionDegrees,
                        windSpeed: snapshot.windSpeed
                    )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)

                    if snapshot.hasThunderstorm {
                        LightningOverlay()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }

                Group {
                    if let snapshot = viewModel.snapshot {
                        weatherContent(snapshot, now: context.date)
                    } else if viewModel.isLoading {
                        loadingView
                    } else {
                        failureView
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.loadWeatherIfNeeded()
        }
        .sheet(isPresented: $isShowingCityList) {
            if let currentLocationSnapshot = viewModel.currentLocationSnapshot ?? viewModel.snapshot {
                CityWeatherListView(
                    currentLocation: cityListCurrentLocation(from: currentLocationSnapshot, subtitle: "My Location"),
                    onSelectCurrentLocation: {
                        Task { await viewModel.showCurrentLocation() }
                    },
                    onSelectCity: { city in
                        Task { await viewModel.showCity(city) }
                    }
                )
            }
        }
    }

    private func weatherContent(_ snapshot: WeatherSnapshot, now: Date) -> some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack {
                    weatherPanel(snapshot, now: now, height: geometry.size.height, topInset: geometry.safeAreaInsets.top)
                }
                .padding(.horizontal, 18)
                .padding(.top, geometry.safeAreaInsets.top + 82)
                .padding(.bottom, 28)
            }
            .refreshable {
                await viewModel.refreshWeather()
            }
            .onAppear {
                selectedHourlyID = snapshot.hourlyForecast.first?.id
            }
            .onChange(of: snapshot.hourlyForecast.first?.id) { _, newValue in
                if selectedHourlyID == nil {
                    selectedHourlyID = newValue
                }
            }
        }
    }

    private func weatherPanel(_ snapshot: WeatherSnapshot, now: Date, height: CGFloat, topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            topBar(snapshot, now: now)
            heroSection(snapshot, now: now)
                .frame(height: 324)
            hourlyStrip(snapshot, now: now)
                .padding(.top, 2)

            Rectangle()
                .fill(panelDivider(snapshot, now: now))
                .frame(height: 1)
                .padding(.top, 18)

            dailyForecastList(snapshot, now: now)
                .padding(.top, 18)

            Rectangle()
                .fill(panelDivider(snapshot, now: now))
                .frame(height: 1)
                .padding(.top, 18)

            sunSchedule(snapshot, now: now)
                .padding(.top, 18)

            Rectangle()
                .fill(panelDivider(snapshot, now: now))
                .frame(height: 1)
                .padding(.top, 18)

            WeatherAttributionFooter(isDaylight: isSunlit(snapshot, now: now))
                .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: 430)
        .frame(minHeight: max(height - topInset - 160, 640), alignment: .top)
    }

    private func topBar(_ snapshot: WeatherSnapshot, now: Date) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.locationName)
                    .font(.klima(.bold, size: 25))
                    .foregroundStyle(primaryTextColor(snapshot, now: now))

                Text(snapshot.timestampLabel)
                    .font(.klima(.book, size: 17))
                    .foregroundStyle(secondaryTextColor(snapshot, now: now))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(sunriseTextBackdropOpacity(snapshot, now: now)))
            )
            .shadow(
                color: .black.opacity(sunriseTextShadowOpacity(snapshot, now: now)),
                radius: 18,
                x: 0,
                y: 8
            )

            Spacer()

            Button {
                isShowingCityList = true
            } label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(snapshot.isDaylight ? 0.55 : 0.10))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "circle.grid.2x2")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(primaryTextColor(snapshot, now: now).opacity(0.72))
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func cityListCurrentLocation(from snapshot: WeatherSnapshot, subtitle: String) -> CityListCurrentLocation {
        CityListCurrentLocation(
            name: snapshot.locationName,
            subtitle: subtitle,
            condition: snapshot.conditionDescription,
            temperature: snapshot.currentTemperature,
            highTemperature: snapshot.highTemperature,
            lowTemperature: snapshot.lowTemperature,
            coordinate: snapshot.coordinate,
            isDaylight: snapshot.isDaylight,
            rainIntensity: snapshot.rainIntensity
        )
    }

    private func heroSection(_ snapshot: WeatherSnapshot, now: Date) -> some View {
        let theme = SkyTheme(snapshot: snapshot, now: now)

        return VStack {
            Spacer(minLength: 0)

            ZStack(alignment: .trailing) {
                ZStack {
                    Image("Night")
                        .resizable()
                        .scaledToFit()
                        .opacity(theme.nightArtworkOpacity)

                    Image("Day")
                        .resizable()
                        .scaledToFit()
                        .opacity(theme.dayArtworkOpacity)
                }
                .frame(width: 432, height: 432)
                .shadow(color: .black.opacity(theme.shadowOpacity), radius: 32, x: 0, y: 20)
                .offset(x: 52, y: -10)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.currentTemperature.temperatureString)
                            .font(.klima(.bold, size: 60))
                            .foregroundStyle(primaryTextColor(snapshot, now: now))
                            .kerning(-2.4)

                        Text(snapshot.conditionDescription)
                            .font(.klima(.medium, size: 21))
                            .foregroundStyle(primaryEmphasisTextColor(snapshot, now: now))

                        Text("Feels like \(snapshot.apparentTemperature.temperatureString)")
                            .font(.klima(.book, size: 16))
                            .foregroundStyle(secondaryTextColor(snapshot, now: now))

                        Text("\(snapshot.highTemperature.temperatureString) / \(snapshot.lowTemperature.temperatureString)")
                            .font(.klima(.demi, size: 18))
                            .foregroundStyle(primaryTextColor(snapshot, now: now))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.black.opacity(sunriseTextBackdropOpacity(snapshot, now: now) * 1.15))
                    )
                    .shadow(
                        color: .black.opacity(sunriseTextShadowOpacity(snapshot, now: now) * 1.1),
                        radius: 24,
                        x: 0,
                        y: 12
                    )
                    .frame(maxWidth: 170, alignment: .leading)
                    .padding(.top, 8)
                    .offset(x: 18, y: -28)

                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hourlyStrip(_ snapshot: WeatherSnapshot, now: Date) -> some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(snapshot.hourlyForecast) { item in
                        let showsPrecipitation = isRainSymbol(item.symbolName) && (item.precipitationChance ?? 0) > 0

                        VStack(spacing: 0) {
                            Text(item.timeLabel)
                                .font(.klima(.medium, size: 12))
                                .foregroundStyle(secondaryTextColor(snapshot, now: now))
                                .frame(height: 14, alignment: .center)

                            Spacer(minLength: 4)

                            VStack(spacing: 5) {
                                Image(systemName: item.symbolName)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(
                                        weatherSymbolPrimaryColor(for: item.symbolName, snapshot: snapshot, now: now),
                                        weatherSymbolSecondaryColor(for: item.symbolName, snapshot: snapshot, now: now),
                                        weatherSymbolTertiaryColor(for: item.symbolName, snapshot: snapshot, now: now)
                                    )
                                    .font(.system(size: 19))
                                    .frame(height: 20, alignment: .center)

                                if showsPrecipitation, let precipitationChance = item.precipitationChance {
                                    Text("\(precipitationChance)%")
                                        .font(.klima(.demi, size: 12))
                                        .foregroundStyle(rainAccentColor(for: item.symbolName, snapshot: snapshot, now: now))
                                        .frame(height: 12, alignment: .center)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .center)

                            Spacer(minLength: 4)

                            if let temperature = item.temperature {
                                Text(temperature.temperatureString)
                                    .font(.klima(.medium, size: 17))
                                    .foregroundStyle(primaryTextColor(snapshot, now: now))
                                    .frame(height: 18, alignment: .center)
                            } else {
                                Text(item.eventLabel ?? "")
                                    .font(.klima(.medium, size: 13))
                                    .foregroundStyle(primaryTextColor(snapshot, now: now))
                                    .frame(height: 18, alignment: .center)
                            }
                        }
                        .frame(width: 52, height: 76, alignment: .top)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedHourlyID, anchor: .center)

            TemperatureTrack(
                tint: primaryTextColor(snapshot, now: now),
                totalTicks: snapshot.hourlyForecast.count,
                selectedIndex: selectedHourlyIndex(in: snapshot)
            )
                .frame(height: 22)
        }
    }

    private func dailyForecastList(_ snapshot: WeatherSnapshot, now: Date) -> some View {
        VStack(spacing: 16) {
            ForEach(snapshot.dailyForecast.prefix(10)) { item in
                HStack(spacing: 14) {
                    Text(item.dayLabel)
                        .font(.klima(.demi, size: 20))
                        .foregroundStyle(primaryTextColor(snapshot, now: now))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 4) {
                        Image(systemName: item.symbolName)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                weatherSymbolPrimaryColor(for: item.symbolName, snapshot: snapshot, now: now),
                                weatherSymbolSecondaryColor(for: item.symbolName, snapshot: snapshot, now: now),
                                weatherSymbolTertiaryColor(for: item.symbolName, snapshot: snapshot, now: now)
                            )
                            .font(.system(size: 18))

                        if isRainSymbol(item.symbolName), item.precipitationChance > 0 {
                            Text("\(item.precipitationChance)%")
                                .font(.klima(.demi, size: 11))
                                .foregroundStyle(rainAccentColor(for: item.symbolName, snapshot: snapshot, now: now))
                        }
                    }
                    .frame(width: 34)

                    Text("\(item.highTemperature.temperatureString) / \(item.lowTemperature.temperatureString)")
                        .font(.klima(.medium, size: 20))
                        .foregroundStyle(primaryTextColor(snapshot, now: now))
                        .frame(minWidth: 86, alignment: .trailing)
                }
            }
        }
    }

    private func selectedHourlyIndex(in snapshot: WeatherSnapshot) -> Int {
        guard
            let selectedHourlyID,
            let selectedIndex = snapshot.hourlyForecast.firstIndex(where: { $0.id == selectedHourlyID })
        else {
            return 0
        }

        return selectedIndex
    }

    private func sunSchedule(_ snapshot: WeatherSnapshot, now: Date) -> some View {
        HStack {
            SunTimeCell(
                icon: "sunrise.fill",
                title: snapshot.sunriseTimeLabel,
                subtitle: "Sunrise",
                snapshot: snapshot,
                now: now
            )

            Spacer()

            SunTimeCell(
                icon: "sun.max.fill",
                title: snapshot.solarNoonTimeLabel,
                subtitle: "Midday",
                snapshot: snapshot,
                now: now
            )

            Spacer()

            SunTimeCell(
                icon: "sunset.fill",
                title: snapshot.sunsetTimeLabel,
                subtitle: "Sunset",
                snapshot: snapshot,
                now: now
            )
        }
    }

    private func isSunlit(_ snapshot: WeatherSnapshot, now: Date) -> Bool {
        isSunlitSnapshot(snapshot, now: now)
    }

    private func primaryTextColor(_ snapshot: WeatherSnapshot, now: Date) -> Color {
        sunriseFadingTextColor(
            snapshot,
            now: now,
            dayColor: .klimaTextDayPrimary,
            nightColor: .klimaTextNightPrimary
        )
    }

    private func secondaryTextColor(_ snapshot: WeatherSnapshot, now: Date) -> Color {
        sunriseFadingTextColor(
            snapshot,
            now: now,
            dayColor: .klimaTextDaySecondary,
            nightColor: .klimaTextNightSecondary
        )
    }

    private func primaryEmphasisTextColor(_ snapshot: WeatherSnapshot, now: Date) -> Color {
        sunriseFadingTextColor(
            snapshot,
            now: now,
            dayColor: .klimaTextDayPrimary,
            nightColor: .klimaTextNightEmphasis
        )
    }

    private func panelDivider(_ snapshot: WeatherSnapshot, now: Date) -> Color {
        isSunlit(snapshot, now: now) ? .klimaDividerDay : .klimaDividerNight
    }

    private func weatherSymbolPrimaryColor(for symbolName: String, snapshot: WeatherSnapshot, now: Date) -> Color {
        let isDay = isSunlit(snapshot, now: now)

        if symbolName == "cloud.snow.fill" {
            return .klimaSnowWhite
        }

        if symbolName == "cloud.fog.fill" {
            return .klimaFogCloud
        }

        if symbolName == "cloud.fill" {
            return .klimaOvercastGray
        }

        if symbolName == "cloud.sun.fill" {
            return .klimaCloudyDay
        }

        if symbolName == "cloud.moon.fill" {
            return .klimaMoonlitCloud
        }

        if symbolName == "cloud.heavyrain.fill" {
            return .klimaHeavyRainCloudDay
        }

        if symbolName == "cloud.rain.fill" || symbolName == "cloud.drizzle.fill" || symbolName == "cloud.sleet.fill" {
            return isDay
                ? .klimaRainCloudDay
                : .klimaRainCloudNight
        }

        if symbolName.contains("bolt") {
            return isDay
                ? .klimaStormLightningDay
                : .klimaStormLightningNight
        }

        if symbolName.contains("rain") || symbolName.contains("drizzle") || symbolName.contains("storm") {
            return isDay
                ? .klimaRainBlueDay
                : .klimaRainBlueNight
        }

        if symbolName.contains("sun") {
            return isDay
                ? .klimaSunOrangeDay
                : .klimaSunOrangeNight
        }

        if symbolName.contains("cloud") {
            return isDay
                ? .klimaCloudSteelBlue
                : .klimaWarmCloudAccent
        }

        return isDay
            ? .klimaWarmAccentDay
            : .klimaWarmAccentNight
    }

    private func weatherSymbolSecondaryColor(for symbolName: String, snapshot: WeatherSnapshot, now: Date) -> Color {
        let isDay = isSunlit(snapshot, now: now)

        if symbolName == "cloud.snow.fill" {
            return .klimaSnowWhite
        }

        if symbolName == "cloud.fog.fill" {
            return .klimaFogCloud
        }

        if symbolName == "cloud.fill" {
            return .klimaOvercastGray
        }

        if symbolName == "cloud.sun.fill" {
            return isDay
                ? .klimaSunOrangeDay
                : .klimaSunOrangeNight
        }

        if symbolName == "cloud.moon.fill" {
            return .klimaMoonTint
        }

        if symbolName == "cloud.heavyrain.fill" {
            return .klimaHeavyRainCloudDay
        }

        if symbolName == "cloud.rain.fill" || symbolName == "cloud.drizzle.fill" || symbolName == "cloud.sleet.fill" {
            return isDay
                ? .klimaRainCloudDay
                : .klimaRainCloudNight
        }

        if symbolName.contains("bolt") {
            return .klimaThunderstormTeal
        }

        if symbolName.contains("rain") || symbolName.contains("drizzle") || symbolName.contains("storm") {
            return isDay
                ? .klimaRainCloudDay
                : .klimaRainCloudNight
        }

        if symbolName.contains("sun") {
            return isDay
                ? .klimaSunHighlightDay
                : .klimaSunHighlightNight
        }

        if symbolName.contains("cloud") {
            return isDay
                ? .klimaCloudSteelBlue
                : .klimaCloudSteelBlue
        }

        return isDay
            ? .klimaAccentSlateDay
            : .klimaAccentSlateNight
    }

    private func weatherSymbolTertiaryColor(for symbolName: String, snapshot: WeatherSnapshot, now: Date) -> Color {
        let isDay = isSunlit(snapshot, now: now)

        if symbolName == "cloud.snow.fill" {
            return .klimaSnowWhite
        }

        if symbolName == "cloud.fog.fill" {
            return .klimaFogCloud
        }

        if symbolName == "cloud.fill" {
            return .klimaOvercastGray
        }

        if symbolName == "cloud.sun.fill" {
            return isDay
                ? .klimaSunHighlightDay
                : .klimaSunHighlightNight
        }

        if symbolName == "cloud.moon.fill" {
            return .klimaMoonHighlight
        }

        if symbolName == "cloud.heavyrain.fill" {
            return .klimaRainDropDay
        }

        if symbolName == "cloud.rain.fill" || symbolName == "cloud.drizzle.fill" || symbolName == "cloud.sleet.fill" {
            return .klimaRainDropDay
        }

        if symbolName.contains("bolt") {
            return isDay
                ? .klimaStormRainDay
                : .klimaStormRainNight
        }

        if symbolName.contains("rain") || symbolName.contains("drizzle") || symbolName.contains("storm") {
            return isDay
                ? .klimaRainDropDay
                : .klimaRainDropNight
        }

        if symbolName.contains("sun") {
            return weatherSymbolSecondaryColor(for: symbolName, snapshot: snapshot, now: now)
        }

        if symbolName.contains("cloud") {
            return isDay
                ? .klimaCloudSteelBlue
                : .klimaCloudSteelBlue
        }

        return weatherSymbolSecondaryColor(for: symbolName, snapshot: snapshot, now: now)
    }

    private func rainAccentColor(for symbolName: String, snapshot: WeatherSnapshot, now: Date) -> Color {
        let isDay = isSunlit(snapshot, now: now)

        if isRainSymbol(symbolName) {
            return isDay ? .klimaRainDropDay : .klimaRainDropNight
        }

        return secondaryTextColor(snapshot, now: now)
    }

    private func isRainSymbol(_ symbolName: String) -> Bool {
        symbolName.contains("rain") || symbolName.contains("drizzle") || symbolName.contains("bolt") || symbolName.contains("sleet")
    }

    private func sunriseTextBackdropOpacity(_ snapshot: WeatherSnapshot, now: Date) -> Double {
        let progress = sunriseFadeProgress(snapshot, now: now)
        guard progress > 0, progress < 1 else { return 0 }
        return (sin(progress * .pi) * 0.22).clamped(to: 0...0.22)
    }

    private func sunriseTextShadowOpacity(_ snapshot: WeatherSnapshot, now: Date) -> Double {
        let progress = sunriseFadeProgress(snapshot, now: now)
        guard progress > 0, progress < 1 else { return 0.12 }
        return (0.12 + (sin(progress * .pi) * 0.22)).clamped(to: 0.12...0.34)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)

            Text("Loading live weather…")
                .font(.klima(.medium, size: 18))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(28)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var failureView: some View {
        VStack(spacing: 14) {
            Text("Weather unavailable")
                .font(.klima(.medium, size: 24))
                .foregroundStyle(.white)

            Text(viewModel.errorMessage ?? "Unable to load forecast data right now.")
                .font(.klima(.book, size: 16))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await viewModel.refreshWeather()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.2))
        }
        .padding(28)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 24)
    }

}

private struct AppBackdrop: View {
    let theme: SkyTheme
    @State private var displayedTheme: SkyTheme?

    private var activeTheme: SkyTheme {
        displayedTheme ?? theme
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: activeTheme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(activeTheme.topGlowColor.opacity(activeTheme.topGlowOpacity))
                .frame(width: 280, height: 280)
                .blur(radius: 34)
                .offset(x: -170, y: -300)

            MovingCloudLayer(theme: activeTheme)
        }
        .onAppear {
            displayedTheme = theme
        }
        .onChange(of: theme.phase) { _, newPhase in
            let previousPhase = displayedTheme?.phase ?? newPhase
            let phaseDelta = abs(newPhase - previousPhase)

            if phaseDelta > 0.04 {
                displayedTheme = theme
            } else {
                withAnimation(.easeInOut(duration: 60)) {
                    displayedTheme = theme
                }
            }
        }
        .onChange(of: theme.cloudSpeedScale) { _, _ in
            displayedTheme = theme
        }
    }
}

private struct MovingCloudLayer: View {
    let theme: SkyTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            GeometryReader { geometry in
                let size = geometry.size
                let seconds = context.date.timeIntervalSinceReferenceDate
                let daylight = isDaylight
                let clouds = theme.hasDenseCloudLayer
                    ? WispyCloudAsset.backdropClouds + WispyCloudAsset.denseBackdropClouds
                    : WispyCloudAsset.backdropClouds

                ZStack {
                    ForEach(clouds) { cloud in
                        movingCloudImage(cloud, size: size, seconds: seconds, isDaylight: daylight)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .mask(alignment: .top) {
                    LinearGradient(
                        colors: [
                            .black,
                            .black,
                            .black.opacity(0.55),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(size.height * 0.56, 450))
                }
            }
        }
        .blur(radius: isDaylight ? 0.45 : 0.9)
        .opacity(theme.cloudLayerOpacity)
        .blendMode(isDaylight ? .normal : .screen)
        .allowsHitTesting(false)
    }

    private var isDaylight: Bool {
        theme.phase >= 0.30 && theme.phase < 0.72
    }

    private func movingCloudImage(
        _ cloud: WispyCloudAsset,
        size: CGSize,
        seconds: TimeInterval,
        isDaylight: Bool
    ) -> some View {
        let width = size.width * cloud.widthRatio
        let travelWidth = size.width + width
        let adjustedDuration = cloud.duration / theme.cloudSpeedScale
        let progress = CGFloat((seconds / adjustedDuration + cloud.phaseOffset).truncatingRemainder(dividingBy: 1))
        let x = -width * 0.5 + travelWidth * progress
        let y = size.height * cloud.yRatio + CGFloat(sin(seconds * cloud.floatSpeed * theme.cloudSpeedScale + cloud.phaseOffset * 6.0)) * cloud.floatAmount
        let opacity = cloud.opacity * (isDaylight ? 1.0 : 0.78)

        return ZStack {
            cloudImage(cloud, width: width, x: x, y: y, opacity: opacity)
            cloudImage(cloud, width: width, x: x - travelWidth, y: y, opacity: opacity)
            cloudImage(cloud, width: width, x: x + travelWidth, y: y, opacity: opacity)
        }
    }

    private func cloudImage(
        _ cloud: WispyCloudAsset,
        width: CGFloat,
        x: CGFloat,
        y: CGFloat,
        opacity: Double
    ) -> some View {
        let height = width * 0.55

        return Image(cloud.assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
        .frame(width: width, height: height)
        .opacity(opacity)
        .blur(radius: cloud.blurRadius)
        .position(x: x + width * 0.5, y: y + height * 0.5)
    }
}

private struct WispyCloudAsset: Identifiable {
    let id: String
    let assetName: String
    let yRatio: CGFloat
    let widthRatio: CGFloat
    let duration: TimeInterval
    let phaseOffset: TimeInterval
    let opacity: Double
    let floatSpeed: Double
    let floatAmount: CGFloat
    let blurRadius: CGFloat
    let isStormCloud: Bool

    init(
        assetName: String,
        yRatio: CGFloat,
        widthRatio: CGFloat,
        duration: TimeInterval,
        phaseOffset: TimeInterval,
        opacity: Double,
        floatSpeed: Double,
        floatAmount: CGFloat,
        blurRadius: CGFloat = 0,
        isStormCloud: Bool = false
    ) {
        self.id = "\(assetName)-\(phaseOffset)"
        self.assetName = assetName
        self.yRatio = yRatio
        self.widthRatio = widthRatio
        self.duration = duration
        self.phaseOffset = phaseOffset
        self.opacity = opacity
        self.floatSpeed = floatSpeed
        self.floatAmount = floatAmount
        self.blurRadius = blurRadius
        self.isStormCloud = isStormCloud
    }

    static let backdropClouds: [WispyCloudAsset] = [
        WispyCloudAsset(assetName: "cloud1", yRatio: -0.08, widthRatio: 1.16, duration: 136, phaseOffset: 0.08, opacity: 0.92, floatSpeed: 0.09, floatAmount: 7),
        WispyCloudAsset(assetName: "cloud2", yRatio: 0.00, widthRatio: 0.96, duration: 108, phaseOffset: 0.42, opacity: 0.86, floatSpeed: 0.13, floatAmount: 9),
        WispyCloudAsset(assetName: "cloud3", yRatio: 0.09, widthRatio: 1.26, duration: 156, phaseOffset: 0.64, opacity: 0.74, floatSpeed: 0.07, floatAmount: 6),
        WispyCloudAsset(assetName: "cloud4", yRatio: 0.17, widthRatio: 1.02, duration: 124, phaseOffset: 0.27, opacity: 0.72, floatSpeed: 0.10, floatAmount: 7),
        WispyCloudAsset(assetName: "cloud9", yRatio: 0.24, widthRatio: 1.18, duration: 148, phaseOffset: 0.73, opacity: 0.66, floatSpeed: 0.08, floatAmount: 6),
        WispyCloudAsset(assetName: "cloud10", yRatio: 0.25, widthRatio: 0.92, duration: 118, phaseOffset: 0.16, opacity: 0.58, floatSpeed: 0.11, floatAmount: 5),
        WispyCloudAsset(assetName: "cloud5", yRatio: 0.34, widthRatio: 1.10, duration: 142, phaseOffset: 0.52, opacity: 0.52, floatSpeed: 0.08, floatAmount: 4),
        WispyCloudAsset(assetName: "cloud6", yRatio: 0.38, widthRatio: 0.96, duration: 132, phaseOffset: 0.81, opacity: 0.48, floatSpeed: 0.09, floatAmount: 4),
        WispyCloudAsset(assetName: "cloud7", yRatio: 0.43, widthRatio: 1.22, duration: 152, phaseOffset: 0.33, opacity: 0.54, floatSpeed: 0.08, floatAmount: 3),
        WispyCloudAsset(assetName: "cloud8", yRatio: 0.47, widthRatio: 1.04, duration: 126, phaseOffset: 0.68, opacity: 0.50, floatSpeed: 0.10, floatAmount: 3),
        WispyCloudAsset(assetName: "cloud19", yRatio: 0.50, widthRatio: 1.36, duration: 166, phaseOffset: 0.12, opacity: 0.46, floatSpeed: 0.07, floatAmount: 3)
    ]

    static let denseBackdropClouds: [WispyCloudAsset] = [
        WispyCloudAsset(assetName: "cloud5", yRatio: -0.03, widthRatio: 1.06, duration: 132, phaseOffset: 0.55, opacity: 0.76, floatSpeed: 0.08, floatAmount: 5),
        WispyCloudAsset(assetName: "cloud6", yRatio: 0.06, widthRatio: 1.24, duration: 152, phaseOffset: 0.31, opacity: 0.70, floatSpeed: 0.07, floatAmount: 6),
        WispyCloudAsset(assetName: "cloud7", yRatio: 0.14, widthRatio: 0.98, duration: 104, phaseOffset: 0.86, opacity: 0.66, floatSpeed: 0.12, floatAmount: 5),
        WispyCloudAsset(assetName: "cloud8", yRatio: 0.22, widthRatio: 1.30, duration: 168, phaseOffset: 0.19, opacity: 0.62, floatSpeed: 0.06, floatAmount: 5),
        WispyCloudAsset(assetName: "cloud17", yRatio: 0.24, widthRatio: 1.10, duration: 126, phaseOffset: 0.68, opacity: 0.58, floatSpeed: 0.09, floatAmount: 4),
        WispyCloudAsset(assetName: "cloud18", yRatio: 0.28, widthRatio: 1.22, duration: 144, phaseOffset: 0.04, opacity: 0.54, floatSpeed: 0.08, floatAmount: 4),
        WispyCloudAsset(assetName: "cloud19", yRatio: 0.36, widthRatio: 1.08, duration: 158, phaseOffset: 0.49, opacity: 0.50, floatSpeed: 0.07, floatAmount: 3),
        WispyCloudAsset(assetName: "cloud10", yRatio: 0.43, widthRatio: 1.26, duration: 148, phaseOffset: 0.25, opacity: 0.54, floatSpeed: 0.08, floatAmount: 3),
        WispyCloudAsset(assetName: "cloud9", yRatio: 0.48, widthRatio: 1.02, duration: 118, phaseOffset: 0.77, opacity: 0.50, floatSpeed: 0.10, floatAmount: 3)
    ]

    static let stormClouds: [WispyCloudAsset] = [
        WispyCloudAsset(assetName: "cloud11", yRatio: -0.20, widthRatio: 1.62, duration: 116, phaseOffset: 0.10, opacity: 1.00, floatSpeed: 0.06, floatAmount: 6, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud12", yRatio: -0.12, widthRatio: 1.38, duration: 88, phaseOffset: 0.44, opacity: 0.96, floatSpeed: 0.08, floatAmount: 7, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud13", yRatio: -0.03, widthRatio: 1.48, duration: 132, phaseOffset: 0.72, opacity: 0.88, floatSpeed: 0.05, floatAmount: 5, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud14", yRatio: 0.07, widthRatio: 1.20, duration: 104, phaseOffset: 0.30, opacity: 0.78, floatSpeed: 0.10, floatAmount: 6, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud15", yRatio: 0.15, widthRatio: 1.32, duration: 142, phaseOffset: 0.58, opacity: 0.72, floatSpeed: 0.07, floatAmount: 5, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud16", yRatio: 0.22, widthRatio: 1.04, duration: 120, phaseOffset: 0.22, opacity: 0.62, floatSpeed: 0.09, floatAmount: 5, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud17", yRatio: 0.03, widthRatio: 1.56, duration: 154, phaseOffset: 0.91, opacity: 0.84, floatSpeed: 0.06, floatAmount: 5, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud18", yRatio: 0.12, widthRatio: 1.24, duration: 96, phaseOffset: 0.66, opacity: 0.76, floatSpeed: 0.10, floatAmount: 5, isStormCloud: true),
        WispyCloudAsset(assetName: "cloud19", yRatio: 0.22, widthRatio: 1.42, duration: 138, phaseOffset: 0.37, opacity: 0.68, floatSpeed: 0.08, floatAmount: 4, isStormCloud: true)
    ]
}

private struct StormCloudImageDeck: View {
    let intensity: RainIntensity
    let isDaylight: Bool
    let windSpeed: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            GeometryReader { geometry in
                let size = geometry.size
                let seconds = context.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(WispyCloudAsset.stormClouds) { cloud in
                        stormCloudImage(cloud, size: size, seconds: seconds)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .mask(alignment: .top) {
                    LinearGradient(
                        colors: [
                            .black,
                            .black,
                            .black.opacity(0.46),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(size.height * 0.54, 430))
                }
            }
        }
        .opacity(deckOpacity)
        .allowsHitTesting(false)
    }

    private var deckOpacity: Double {
        switch intensity {
        case .none: 0
        case .light: isDaylight ? 0.62 : 0.70
        case .medium: isDaylight ? 0.82 : 0.88
        case .heavy: isDaylight ? 0.96 : 1.0
        }
    }

    private func stormCloudImage(
        _ cloud: WispyCloudAsset,
        size: CGSize,
        seconds: TimeInterval
    ) -> some View {
        let width = size.width * cloud.widthRatio
        let travelWidth = size.width + width
        let intensityScale = intensity == .heavy ? 1.18 : 1.0
        let adjustedDuration = cloud.duration / (Self.cloudSpeedScale(for: windSpeed) * intensityScale)
        let progress = CGFloat((seconds / adjustedDuration + cloud.phaseOffset).truncatingRemainder(dividingBy: 1))
        let x = -width * 0.52 + travelWidth * progress
        let y = size.height * cloud.yRatio + CGFloat(sin(seconds * cloud.floatSpeed * Self.cloudSpeedScale(for: windSpeed) + cloud.phaseOffset * 6.0)) * cloud.floatAmount
        let opacity = cloud.opacity * (intensity == .heavy ? 1.0 : 0.82)

        return ZStack {
            stormImage(cloud, width: width, x: x, y: y, opacity: opacity)
            stormImage(cloud, width: width, x: x - travelWidth, y: y, opacity: opacity)
            stormImage(cloud, width: width, x: x + travelWidth, y: y, opacity: opacity)
        }
    }

    private func stormImage(
        _ cloud: WispyCloudAsset,
        width: CGFloat,
        x: CGFloat,
        y: CGFloat,
        opacity: Double
    ) -> some View {
        let height = width * 0.55

        return Image(cloud.assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .opacity(opacity)
            .blur(radius: cloud.blurRadius)
            .position(x: x + width * 0.5, y: y + height * 0.5)
    }

    private static func cloudSpeedScale(for windSpeed: Double) -> Double {
        min(max(0.55 + (windSpeed / 18.0), 0.55), 2.6)
    }
}

private struct StormCloudCeilingOverlay: View {
    let intensity: RainIntensity
    let windDirectionDegrees: Int
    let windSpeed: Double
    let isDaylight: Bool

    var body: some View {
        ZStack {
            StormCloudImageDeck(intensity: intensity, isDaylight: isDaylight, windSpeed: windSpeed)
            ImageRainLayer(
                intensity: intensity,
                windDirectionDegrees: windDirectionDegrees,
                windSpeed: windSpeed,
                startYRatio: 0.12,
                heightRatio: 0.72,
                densityMultiplier: 1.18,
                opacityMultiplier: 0.86
            )
        }
        .blur(radius: intensity == .heavy ? 0.25 : 0.45)
        .opacity(deckOpacity)
        .allowsHitTesting(false)
    }

    private var deckOpacity: Double {
        switch intensity {
        case .none: 0
        case .light: isDaylight ? 0.58 : 0.64
        case .medium: isDaylight ? 0.76 : 0.82
        case .heavy: isDaylight ? 0.92 : 0.96
        }
    }

}

private struct ImageRainLayer: View {
    let intensity: RainIntensity
    let windDirectionDegrees: Int
    let windSpeed: Double
    let startYRatio: CGFloat
    let heightRatio: CGFloat
    let densityMultiplier: Double
    let opacityMultiplier: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { geometry in
                let size = geometry.size
                let seconds = context.date.timeIntervalSinceReferenceDate
                let dropCount = Int(Double(intensity.dropCount) * densityMultiplier)

                ZStack {
                    ForEach(0..<dropCount, id: \.self) { index in
                        rainDrop(index: index, size: size, seconds: seconds)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .allowsHitTesting(false)
    }

    private func rainDrop(index: Int, size: CGSize, seconds: TimeInterval) -> some View {
        let seed = Double(index) * 12.9898 + 78.233
        let xRandom = random(seed)
        let yRandom = random(seed + 11.7)
        let speedRandom = random(seed + 23.4)
        let scaleRandom = random(seed + 35.1)
        let opacityRandom = random(seed + 46.8)
        let driftRandom = random(seed + 58.5) - 0.5
        let assetIndex = min(
            max(Int(random(seed + 70.2) * Double(RainDropAsset.names.count)), 0),
            RainDropAsset.names.count - 1
        )
        let assetName = RainDropAsset.names[assetIndex]

        let fallAreaHeight = size.height * heightRatio
        let startY = size.height * startYRatio
        let speed = intensity.speed * (0.58 + speedRandom * 0.78)
        let phase = (seconds * speed + yRandom).truncatingRemainder(dividingBy: 1)
        let dropScale = 0.58 + scaleRandom * 0.94
        let dropWidth = baseDropWidth * dropScale
        let slant = rainSlant * (0.62 + random(seed + 91.3) * 0.64)
        let xJitter = CGFloat(sin(seconds * (0.18 + speedRandom * 0.20) + seed)) * CGFloat(4 + speedRandom * 12)
        let x = CGFloat(xRandom) * (size.width + dropWidth * 2) - dropWidth + xJitter + CGFloat(driftRandom) * 26
        let y = startY + CGFloat(phase) * (fallAreaHeight + dropWidth * 6) - dropWidth * 3
        let opacity = (0.32 + opacityRandom * 0.58) * opacityMultiplier

        return Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.klimaRainAnimationGray)
            .frame(width: dropWidth)
            .opacity(max(opacity, 0.48))
            .rotationEffect(.degrees(Double(rainSlant) * 18))
            .position(x: x + slant * CGFloat(phase) * 28, y: y)
    }

    private var baseDropWidth: CGFloat {
        switch intensity {
        case .none: 0
        case .light: 6
        case .medium: 8
        case .heavy: 10
        }
    }

    private var rainSlant: CGFloat {
        let normalized = Double((windDirectionDegrees % 360 + 360) % 360)
        let horizontal = sin(normalized * .pi / 180)
        return CGFloat(horizontal * min(max(windSpeed / 26.0, 0.12), 0.60))
    }

    private func random(_ seed: Double) -> Double {
        let value = sin(seed) * 43_758.5453
        return value - floor(value)
    }
}

private struct RainDropAsset {
    static let names = (1...30).map { index in
        "raindrop_\(String(format: "%02d", index))"
    }
}

private struct RainOverlay: View {
    let intensity: RainIntensity
    let windDirectionDegrees: Int
    let windSpeed: Double

    var body: some View {
        ZStack {
            ImageRainLayer(
                intensity: intensity,
                windDirectionDegrees: windDirectionDegrees,
                windSpeed: windSpeed,
                startYRatio: -0.08,
                heightRatio: 1.18,
                densityMultiplier: 1.0,
                opacityMultiplier: 0.78
            )

            TimelineView(.animation) { context in
                Canvas { context2D, size in
                    drawRainSplashes(
                        in: &context2D,
                        size: size,
                        seconds: context.date.timeIntervalSinceReferenceDate
                    )
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(intensity.opacity * 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .blur(radius: 14)
                .allowsHitTesting(false)
            }
        }
        .blur(radius: intensity == .heavy ? 0.18 : 0)
        .allowsHitTesting(false)
    }

    private var rainAngle: CGFloat {
        let normalized = Double((windDirectionDegrees % 360 + 360) % 360)
        let signedHorizontal = sin(normalized * .pi / 180)
        let windContribution = signedHorizontal * min(max(windSpeed / 18.0, 0.15), 0.95)
        return CGFloat(0.10 + (windContribution * 0.32))
    }

    private func drawRainLayer(
        in context2D: inout GraphicsContext,
        size: CGSize,
        seconds: TimeInterval,
        angle: CGFloat,
        dropCount: Int,
        speedMultiplier: Double,
        lengthMultiplier: CGFloat,
        width: CGFloat,
        opacityMultiplier: Double
    ) {
        let dropLength = intensity.length * lengthMultiplier
        let dx = sin(angle) * dropLength
        let dy = cos(angle) * dropLength

        for index in 0..<dropCount {
            let seed = Double(index) * 0.61803398875
            let xBase = CGFloat((seed * 137.5).truncatingRemainder(dividingBy: 1))
            let yBase = CGFloat((seed * 91.7).truncatingRemainder(dividingBy: 1))
            let laneOffset = CGFloat((seed * 57.3).truncatingRemainder(dividingBy: 1))
            let speedJitter = 0.72 + ((seed * 23.0).truncatingRemainder(dividingBy: 0.56))
            let laneDrift = CGFloat(((seed * 11.0).truncatingRemainder(dividingBy: 1)) - 0.5)

            let xJitter = CGFloat(sin(seconds * (0.23 + seed * 0.015) + seed * 6.1)) * (2.2 + CGFloat(seed.truncatingRemainder(dividingBy: 1)) * 4.6)
            let phaseOffset = (seed * 17.0).truncatingRemainder(dividingBy: 1)
            let x = (xBase * size.width) + (laneOffset * 18) - 12 + (laneDrift * 26) + xJitter
            let travel = CGFloat((seconds * intensity.speed * speedMultiplier * speedJitter + Double(yBase) + phaseOffset).truncatingRemainder(dividingBy: 1))
            let y = travel * (size.height + dropLength * 3) - dropLength * 2

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx, y: y + dy))

            let alpha = intensity.opacity * opacityMultiplier * (0.55 + Double(laneOffset) * 0.45)
            context2D.stroke(
                path,
                with: .color(Color.klimaRainDropDay.opacity(max(alpha * 2.1, 0.08))),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }
    }

    private func drawRainSplashes(
        in context2D: inout GraphicsContext,
        size: CGSize,
        seconds: TimeInterval
    ) {
        guard intensity.splashCount > 0 else { return }

        for index in 0..<intensity.splashCount {
            let seed = Double(index) * 0.754877666
            let xBase = CGFloat((seed * 41.2).truncatingRemainder(dividingBy: 1))
            let cycle = (seconds * (0.28 + Double(index % 4) * 0.04) + seed).truncatingRemainder(dividingBy: 1)
            let pulse = sin(cycle * .pi)
            let alpha = max(0, pulse) * intensity.opacity * 0.42

            guard alpha > 0.02 else { continue }

            let splashWidth = 10 + CGFloat(index % 4) * 3
            let splashRect = CGRect(
                x: xBase * size.width,
                y: size.height - 38 - CGFloat(index % 4) * 5,
                width: splashWidth,
                height: 2.2
            )

            context2D.fill(
                Capsule().path(in: splashRect),
                with: .color(Color.klimaRainDropDay.opacity(max(alpha * 1.8, 0.06)))
            )

            let glowRect = splashRect.insetBy(dx: -8, dy: -5)
            context2D.fill(
                Ellipse().path(in: glowRect),
                with: .color(Color.klimaRainDropDay.opacity(alpha * 0.32))
            )
        }
    }
}

private struct LightningOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 18)
            let primaryPulse = flashEnvelope(time: cycle, start: 1.8, duration: 0.18, peak: 0.18)
            let secondaryPulse = flashEnvelope(time: cycle, start: 7.4, duration: 0.12, peak: 0.10)
            let tertiaryPulse = flashEnvelope(time: cycle, start: 13.9, duration: 0.22, peak: 0.14)
            let flash = max(primaryPulse, secondaryPulse, tertiaryPulse)

            GeometryReader { geometry in
                ZStack {
                    Color.klimaWhite
                        .opacity(flash * 0.22)

                    RadialGradient(
                        colors: [
                            .white.opacity(flash * 0.48),
                            Color.klimaLightningFlashBlue.opacity(flash * 0.18),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 12,
                        endRadius: 340
                    )
                    .blur(radius: 10)
                    .offset(x: 80, y: -120)

                    if flash > 0.035 {
                        Canvas { context2D, size in
                            drawFork(
                                in: &context2D,
                                size: size,
                                flash: flash,
                                originX: size.width * 0.78,
                                originY: size.height * 0.07,
                                scale: min(size.width, size.height) * 0.19,
                                seed: 1.0
                            )

                            if flash > 0.08 {
                                drawFork(
                                    in: &context2D,
                                    size: size,
                                    flash: flash * 0.7,
                                    originX: size.width * 0.68,
                                    originY: size.height * 0.11,
                                    scale: min(size.width, size.height) * 0.12,
                                    seed: 2.0
                                )
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
        }
    }

    private func flashEnvelope(time: TimeInterval, start: TimeInterval, duration: TimeInterval, peak: Double) -> Double {
        guard time >= start, time <= start + duration else { return 0 }
        let progress = (time - start) / duration
        let ramp = sin(progress * .pi)
        return ramp * peak
    }

    private func drawFork(
        in context2D: inout GraphicsContext,
        size: CGSize,
        flash: Double,
        originX: CGFloat,
        originY: CGFloat,
        scale: CGFloat,
        seed: Double
    ) {
        var path = Path()
        path.move(to: CGPoint(x: originX, y: originY))

        let points = lightningPoints(originX: originX, originY: originY, scale: scale, seed: seed)
        for point in points {
            path.addLine(to: point)
        }

        let glowWidth = max(2.0, scale * 0.024)
        let coreWidth = max(0.9, glowWidth * 0.42)

        context2D.stroke(
            path,
            with: .color(Color.klimaWhite(flash * 0.16)),
            style: StrokeStyle(lineWidth: glowWidth, lineCap: .round, lineJoin: .round)
        )
        context2D.stroke(
            path,
            with: .color(Color.klimaStormFlashGlow.opacity(flash * 0.42)),
            style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func lightningPoints(originX: CGFloat, originY: CGFloat, scale: CGFloat, seed: Double) -> [CGPoint] {
        let offsets: [(CGFloat, CGFloat)] = [
            (0.0, 0.0),
            (-0.06, 0.14),
            (0.03, 0.28),
            (-0.11, 0.42),
            (-0.02, 0.58),
            (-0.15, 0.76)
        ]

        return offsets.enumerated().map { index, offset in
            let variation = CGFloat(sin(Double(index) * 1.9 + seed) * 0.035)
            return CGPoint(
                x: originX + (offset.0 + variation) * scale,
                y: originY + offset.1 * scale
            )
        }
    }
}

private struct MistOverlay: View {
    let intensity: RainIntensity
    let isDaylight: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            ZStack {
                Canvas { context2D, size in
                    let seconds = context.date.timeIntervalSinceReferenceDate
                    let bandCount = intensity == .heavy ? 5 : 3

                    for index in 0..<bandCount {
                        let seed = Double(index) * 0.173_205_08
                        let drift = (seconds * (0.006 + Double(index) * 0.0015) + seed).truncatingRemainder(dividingBy: 1)
                        let x = (CGFloat(drift) * (size.width + 180)) - 90
                        let yBase = size.height * (0.22 + CGFloat(index) * 0.12)
                        let width = size.width * (0.72 + CGFloat(index) * 0.08)
                        let height = CGFloat(58 + index * 18)

                        let rect = CGRect(x: x - width / 2, y: yBase, width: width, height: height)
                        let alpha = baseBandOpacity * (0.92 - Double(index) * 0.12)

                        context2D.fill(
                            Ellipse().path(in: rect),
                            with: .color(mistColor.opacity(alpha))
                        )
                    }
                }
                .blur(radius: 28)

                LinearGradient(
                    colors: [
                        mistColor.opacity(0.0),
                        mistColor.opacity(bottomFogOpacity * 0.55),
                        mistColor.opacity(bottomFogOpacity)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .blur(radius: 18)
            }
        }
    }

    private var mistColor: Color {
        isDaylight ? .klimaWhite : .klimaMoonTint
    }

    private var baseBandOpacity: Double {
        switch intensity {
        case .none: 0
        case .light: 0.07
        case .medium: 0.11
        case .heavy: 0.16
        }
    }

    private var bottomFogOpacity: Double {
        switch intensity {
        case .none: 0
        case .light: 0.10
        case .medium: 0.16
        case .heavy: 0.22
        }
    }
}

private struct SkyTheme {
    let phase: Double
    var gradientColors: [Color]
    let topGlowColor: Color
    let topGlowOpacity: Double
    let bottomGlowOpacity: Double
    let dayArtworkOpacity: Double
    let nightArtworkOpacity: Double
    let shadowOpacity: Double
    let cloudLayerOpacity: Double
    let cloudSpeedScale: Double
    let hasDenseCloudLayer: Bool

    init(snapshot: WeatherSnapshot?, now: Date) {
        let nightColors = [
            Color.klimaBackdropNightTop,
            .klimaBackdropNightMid,
            .klimaBackdropNightBottom
        ]

        let sunriseColors = [
            Color.klimaBackdropSunriseTop,
            .klimaBackdropSunriseMid,
            .klimaBackdropSunriseBottom
        ]

        let defaultDayColors = Self.dayBackdropGradient()

        let sunsetColors = [
            Color.klimaBackdropSunsetTop,
            .klimaBackdropSunsetMid,
            .klimaBackdropSunsetBottom
        ]

        func interpolate(_ from: [Color], _ to: [Color], progress: Double) -> [Color] {
            zip(from, to).map { start, end in
                Color(
                    red: start.components.red + (end.components.red - start.components.red) * progress,
                    green: start.components.green + (end.components.green - start.components.green) * progress,
                    blue: start.components.blue + (end.components.blue - start.components.blue) * progress
                )
            }
        }

        let transitionDuration: TimeInterval = 105 * 60

        if
            let snapshot,
            let sunrise = snapshot.sunriseDate,
            let sunset = snapshot.sunsetDate
        {
            if now < sunrise {
                phase = 0
                gradientColors = nightColors
            } else if now < sunrise.addingTimeInterval(transitionDuration) {
                let progress = (now.timeIntervalSince(sunrise) / transitionDuration).clamped(to: 0...1)
                phase = progress * 0.5
                gradientColors = interpolate(sunriseColors, defaultDayColors, progress: progress)
            } else if now < sunset {
                phase = 1
                gradientColors = defaultDayColors
            } else if now < sunset.addingTimeInterval(transitionDuration) {
                let progress = (now.timeIntervalSince(sunset) / transitionDuration).clamped(to: 0...1)
                phase = 1 - (progress * 0.5)
                gradientColors = interpolate(sunsetColors, nightColors, progress: progress)
            } else {
                phase = 0
                gradientColors = nightColors
            }
        } else {
            phase = snapshot?.isDaylight == true ? 1 : 0
            gradientColors = snapshot?.isDaylight == true ? defaultDayColors : nightColors
        }

        let artworkBlend = phase * phase * (3 - (2 * phase))
        let conditionText = snapshot?.conditionDescription.lowercased() ?? ""
        let symbolText = snapshot?.hourlyForecast.first?.symbolName.lowercased() ?? ""
        let isThunder = snapshot?.hasThunderstorm == true
            || conditionText.contains("thunder")
            || symbolText.contains("bolt")
        let isDrizzle = conditionText.contains("drizzle")
            || symbolText.contains("drizzle")
        let isRaining = (snapshot?.rainIntensity ?? RainIntensity.none) != RainIntensity.none
            || conditionText.contains("rain")
            || symbolText.contains("rain")

        if phase > 0.55 {
            if isThunder {
                gradientColors = Self.backdropGradient(from: .klimaBackdropThunderBase)
            } else if isDrizzle {
                gradientColors = Self.backdropGradient(from: .klimaBackdropDrizzleBase)
            } else if isRaining {
                gradientColors = Self.backdropGradient(from: .klimaBackdropRainBase)
            } else {
                gradientColors = defaultDayColors
            }
        }

        topGlowColor = phase > 0.55 ? .klimaWhite : .klimaTopGlowBlue
        topGlowOpacity = isRaining || isThunder ? 0.08 : 0.14 + (phase * 0.42)
        bottomGlowOpacity = isRaining || isThunder ? 0.08 : 0.05 + (phase * 0.33)
        dayArtworkOpacity = artworkBlend
        nightArtworkOpacity = 1 - artworkBlend
        shadowOpacity = 0.18 + ((1 - phase) * 0.12)

        let hasCloudyCondition = conditionText.contains("cloud")
            || conditionText.contains("overcast")
            || conditionText.contains("fog")
            || conditionText.contains("haze")
        hasDenseCloudLayer = hasCloudyCondition || isRaining || isDrizzle || isThunder
        let baseCloudOpacity = phase > 0.55 ? 0.58 : 0.42
        cloudLayerOpacity = hasDenseCloudLayer ? min(baseCloudOpacity + 0.38, 0.96) : baseCloudOpacity
        cloudSpeedScale = Self.cloudSpeedScale(for: snapshot?.windSpeed ?? 6)
    }

    private static func backdropGradient(from color: Color) -> [Color] {
        [
            color.opacity(0.94),
            color,
            color.opacity(0.88)
        ]
    }

    private static func dayBackdropGradient() -> [Color] {
        [
            .klimaBackdropDayBlueTop,
            .klimaBackdropDayBlueTop.opacity(0.96),
            .klimaBackdropDayBlueBottom
        ]
    }

    private static func cloudSpeedScale(for windSpeed: Double) -> Double {
        min(max(0.55 + (windSpeed / 18.0), 0.55), 2.6)
    }
}

private extension Color {
    var components: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
        #else
        return (0, 0, 0)
        #endif
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private func isSunlitSnapshot(_ snapshot: WeatherSnapshot, now: Date) -> Bool {
    guard
        let sunrise = snapshot.sunriseDate,
        let sunset = snapshot.sunsetDate
    else {
        return snapshot.isDaylight
    }

    return now >= sunrise && now < sunset
}

private let sunriseTextFadeDuration: TimeInterval = 45 * 60

private func sunriseFadeProgress(_ snapshot: WeatherSnapshot, now: Date) -> Double {
    guard let sunrise = snapshot.sunriseDate else {
        return snapshot.isDaylight ? 1 : 0
    }

    if now < sunrise {
        return 0
    }

    let fadeEnd = sunrise.addingTimeInterval(sunriseTextFadeDuration)
    if now < fadeEnd {
        return (now.timeIntervalSince(sunrise) / sunriseTextFadeDuration).clamped(to: 0...1)
    }

    return isSunlitSnapshot(snapshot, now: now) ? 1 : 0
}

private func sunriseFadingTextColor(
    _ snapshot: WeatherSnapshot,
    now: Date,
    dayColor: Color,
    nightColor: Color
) -> Color {
    let progress = sunriseFadeProgress(snapshot, now: now)
    let nightComponents = nightColor.components
    let dayComponents = dayColor.components

    return Color(
        red: nightComponents.red + (dayComponents.red - nightComponents.red) * progress,
        green: nightComponents.green + (dayComponents.green - nightComponents.green) * progress,
        blue: nightComponents.blue + (dayComponents.blue - nightComponents.blue) * progress
    )
}

private struct TemperatureTrack: View {
    let tint: Color
    let totalTicks: Int
    let selectedIndex: Int

    var body: some View {
        Canvas { context, size in
            let safeTickCount = max(totalTicks, 1)
            let step = safeTickCount > 1 ? size.width / CGFloat(safeTickCount - 1) : 0

            for index in 0..<safeTickCount {
                let distance = abs(index - selectedIndex)
                let isNeighbor = distance <= 2
                let height: CGFloat
                let yOffset: CGFloat

                switch distance {
                case 0:
                    height = 18
                    yOffset = -6
                case 1:
                    height = 13
                    yOffset = -3
                case 2:
                    height = 10
                    yOffset = -1
                default:
                    height = 7
                    yOffset = 0
                }

                let xPosition = step * CGFloat(index)
                let rect = CGRect(
                    x: xPosition - 1.5,
                    y: (size.height - height) / 2 + yOffset,
                    width: 3,
                    height: height
                )

                context.fill(
                    Capsule().path(in: rect),
                    with: .color(tint.opacity(isNeighbor ? 0.82 : 0.16))
                )
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedIndex)
    }
}

private struct SunTimeCell: View {
    let icon: String
    let title: String
    let subtitle: String
    let snapshot: WeatherSnapshot
    let now: Date

    private func textColor(dayColor: Color, nightColor: Color) -> Color {
        sunriseFadingTextColor(snapshot, now: now, dayColor: dayColor, nightColor: nightColor)
    }

    private var iconColor: Color {
        let isDay = isSunlitSnapshot(snapshot, now: now)

        if icon.contains("sunrise") {
            return isDay
                ? .klimaSunriseIconDay
                : .klimaSunriseIconNight
        }

        if icon.contains("sunset") {
            return isDay
                ? .klimaSunsetIconDay
                : .klimaSunsetIconNight
        }

        return isDay
            ? .klimaSunScheduleIconDay
            : .klimaSunScheduleIconNight
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.klima(.demi, size: 18))
                .foregroundStyle(textColor(dayColor: .klimaTextDayPrimary, nightColor: .klimaTextNightPrimary))

            Text(subtitle)
                .font(.klima(.book, size: 14))
                .foregroundStyle(textColor(dayColor: .klimaTextDayTertiary, nightColor: .klimaTextNightTertiary))
        }
        .frame(maxWidth: .infinity)
    }
}

extension Int {
    var temperatureString: String {
        "\(self)°"
    }
}

private extension Font {
    static func klima(_ style: KlimaFontStyle, size: CGFloat) -> Font {
        .custom(style.rawValue, size: size)
    }
}

private enum KlimaFontStyle: String {
    case bold = "FuturaPTBold"
    case book = "FuturaPTBook"
    case demi = "FuturaPTDemi"
    case light = "FuturaPTLight"
    case medium = "FuturaPTMedium"
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
