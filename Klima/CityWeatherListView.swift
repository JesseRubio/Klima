//
//  CityWeatherListView.swift
//  Klima
//
//  Created by Jesse Rubio on 8/18/25.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

struct CityListCurrentLocation {
    let name: String
    let subtitle: String
    let condition: String
    let temperature: Int
    let highTemperature: Int
    let lowTemperature: Int
    let coordinate: CLLocationCoordinate2D
    let isDaylight: Bool
    let rainIntensity: RainIntensity
}

private enum TemperatureUnit {
    case celsius
    case fahrenheit
}

struct CityWeatherListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CityWeatherListViewModel
    @State private var isShowingOptionsMenu = false
    @State private var isShowingSearchView = false
    @State private var selectedTemperatureUnit: TemperatureUnit = .fahrenheit
    private let onSelectCurrentLocation: (() -> Void)?
    private let onSelectCity: ((StoredCity) -> Void)?

    init(
        currentLocation: CityListCurrentLocation,
        onSelectCurrentLocation: (() -> Void)? = nil,
        onSelectCity: ((StoredCity) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: CityWeatherListViewModel(currentLocation: currentLocation))
        self.onSelectCurrentLocation = onSelectCurrentLocation
        self.onSelectCity = onSelectCity
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    listBackground

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            header

                            VStack(spacing: 10) {
                                CurrentLocationWeatherCard(location: viewModel.currentLocation) {
                                    onSelectCurrentLocation?()
                                    dismiss()
                                }

                                ForEach(viewModel.savedCities) { city in
                                    SavedCityWeatherCard(
                                        city: city,
                                        onSelect: {
                                            onSelectCity?(city.storedCity)
                                            dismiss()
                                        },
                                        remove: {
                                        viewModel.removeCity(city.id)
                                        }
                                    )
                                }
                            }

                            WeatherAttributionFooter(isDaylight: viewModel.currentLocation.isDaylight)
                                .padding(.top, 6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, geometry.safeAreaInsets.top + 28)
                        .padding(.bottom, 120)
                    }

                    if isShowingOptionsMenu {
                        Color.klimaBlack(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                isShowingOptionsMenu = false
                            }

                        VStack {
                            HStack {
                                Spacer()
                                optionsMenu
                            }
                            Spacer()
                        }
                        .padding(.top, geometry.safeAreaInsets.top + 52)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    }
                }
                .ignoresSafeArea()
                .safeAreaInset(edge: .bottom) {
                    searchBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.refreshSavedCities()
            }
            .fullScreenCover(isPresented: $isShowingSearchView) {
                CitySearchView(
                    viewModel: viewModel,
                    currentLocation: viewModel.currentLocation,
                    onClose: {
                        isShowingSearchView = false
                    },
                    onSelectCurrentLocation: {
                        onSelectCurrentLocation?()
                        dismiss()
                    }
                )
            }
        }
    }

    private var listBackground: some View {
        ZStack {
            if viewModel.currentLocation.isDaylight {
                Color.klimaListDayBase

                LinearGradient(
                    colors: [
                        Color.klimaListDayTop,
                        .klimaListDayMid,
                        .klimaListDayBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.klimaWhite(0.45))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: -120, y: -340)

                Circle()
                    .fill(Color.klimaListSunGlow.opacity(0.50))
                    .frame(width: 240, height: 240)
                    .blur(radius: 70)
                    .offset(x: 130, y: -290)
            } else {
                Color.klimaListNightBase

                LinearGradient(
                    colors: [
                        Color.klimaListNightTop.opacity(0.92),
                        .klimaListNightBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.klimaWhite(0.05))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: -120, y: -340)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Weather")
                .font(.klima(.bold, size: 28))
                .foregroundStyle(.white)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    isShowingOptionsMenu.toggle()
                }
            } label: {
                Circle()
                    .fill(Color.klimaWhite(isShowingOptionsMenu ? 0.09 : 0.035))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private var optionsMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            optionsMenuButton("Edit List", icon: .system("pencil"))
            optionsMenuButton("Notifications", icon: .system("bell.badge"))

            optionsMenuDivider

            optionsMenuButton(
                "Celsius",
                icon: .text("°C"),
                showsSelection: selectedTemperatureUnit == .celsius
            ) {
                selectedTemperatureUnit = .celsius
            }
            optionsMenuButton(
                "Fahrenheit",
                icon: .text("°F"),
                showsSelection: selectedTemperatureUnit == .fahrenheit
            ) {
                selectedTemperatureUnit = .fahrenheit
            }

            optionsMenuDivider

            optionsMenuButton("Units", icon: .system("chart.bar"))

            optionsMenuDivider

            optionsMenuButton("Report an Issue", icon: .system("exclamationmark.bubble"))
        }
        .padding(.vertical, 8)
        .frame(width: 214, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.klimaMenuOverlay.opacity(0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 14)
    }

    private enum OptionsMenuIcon {
        case system(String)
        case text(String)
    }

    @ViewBuilder
    private func optionsMenuIconView(_ icon: OptionsMenuIcon?) -> some View {
        switch icon {
        case .system(let symbol):
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
        case .text(let value):
            Text(value)
                .font(.klima(.medium, size: 16))
        case nil:
            EmptyView()
        }
    }

    private func optionsMenuButton(_ title: String) -> some View {
        optionsMenuButton(title, icon: nil)
    }

    private func optionsMenuButton(
        _ title: String,
        icon: OptionsMenuIcon?,
        showsSelection: Bool = false,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button {
            action()
            isShowingOptionsMenu = false
        } label: {
            HStack(spacing: 12) {
                optionsMenuIconView(icon)
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: icon == nil ? 0 : 22, alignment: .leading)

                Text(title)
                    .font(.klima(.book, size: 17))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showsSelection {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    private var optionsMenuDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
    }

    private var searchBar: some View {
        Button {
            isShowingSearchView = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))

                Text("Search for a city or airport")
                    .font(.klima(.book, size: 17))
                    .foregroundStyle(.white.opacity(0.42))

                Spacer()

                Image(systemName: "mic")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.klimaSearchSurface.opacity(0.96))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(.clear)
    }
}

@MainActor
private final class CityWeatherListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var currentLocation: CityListCurrentLocation
    @Published private(set) var savedCities: [SavedCityWeather] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchResults: [CitySearchResult] = []

    private let defaultsKey = "tracked_city_weather_list"
    private let searchService = CityLookupService()
    private let weatherService = KlimaWeatherService()
    private var searchTask: Task<Void, Never>?

    init(currentLocation: CityListCurrentLocation) {
        self.currentLocation = currentLocation
    }

    func refreshSavedCities() async {
        let stored = loadStoredCities()
        await refresh(storedCities: stored)
    }

    @discardableResult
    func addCityFromSearch() async -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return false }

        isSearching = true
        defer { isSearching = false }

        if let firstSuggestion = searchResults.first {
            return await addSearchResult(firstSuggestion)
        }

        guard let result = await searchService.resolve(query: query) else { return false }
        return await persistAndRefresh(with: result)
    }

    @discardableResult
    func addSearchResult(_ result: CitySearchResult) async -> Bool {
        await persistAndRefresh(with: result.storedCity)
    }

    func removeCity(_ id: UUID) {
        let remaining = loadStoredCities().filter { $0.id != id }
        persist(remaining)
        savedCities.removeAll { $0.id == id }
    }

    func scheduleSearchSuggestions(for query: String) {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let results = await self?.searchService.search(query: trimmedQuery) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.searchResults = results
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
    }

    private func refresh(storedCities: [StoredCity]) async {
        var refreshed: [SavedCityWeather] = []

        for city in storedCities {
            if let weather = try? await weatherService.fetchSavedCityWeather(city: city) {
                refreshed.append(weather)
            }
        }

        savedCities = refreshed
    }

    private func loadStoredCities() -> [StoredCity] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([StoredCity].self, from: data)) ?? []
    }

    private func persist(_ cities: [StoredCity]) {
        guard let data = try? JSONEncoder().encode(cities) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func persistAndRefresh(with city: StoredCity) async -> Bool {
        var stored = loadStoredCities()

        if stored.contains(where: { $0.matches(city) }) {
            searchText = ""
            searchResults = []
            return false
        }

        stored.append(city)
        persist(stored)
        searchText = ""
        searchResults = []
        await refresh(storedCities: stored)
        return true
    }
}

private struct CitySearchView: View {
    @ObservedObject var viewModel: CityWeatherListViewModel
    let currentLocation: CityListCurrentLocation
    let onClose: () -> Void
    let onSelectCurrentLocation: () -> Void
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.klimaBlack
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            suggestedSection
                        } else {
                            searchResultsSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 160)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomSearchBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isSearchFieldFocused = true
                viewModel.scheduleSearchSuggestions(for: viewModel.searchText)
            }
            .onDisappear {
                viewModel.clearSearch()
            }
        }
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUGGESTED")
                .font(.klima(.book, size: 11))
                .foregroundStyle(.white.opacity(0.24))

            Button {
                onSelectCurrentLocation()
                onClose()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text("Home")
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                    .font(.klima(.medium, size: 18))
                    .foregroundStyle(.white.opacity(0.92))

                    Text(currentLocation.subtitle)
                        .font(.klima(.book, size: 16))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isSearching && viewModel.searchResults.isEmpty {
                HStack {
                    ProgressView()
                        .tint(.white.opacity(0.75))
                    Spacer()
                }
                .padding(.top, 12)
            }

            ForEach(viewModel.searchResults) { result in
                Button {
                    Task {
                        let added = await viewModel.addSearchResult(result)
                        if added {
                            onClose()
                        }
                    }
                } label: {
                    HStack(spacing: 0) {
                        Text(result.storedCity.name)
                            .font(.klima(.medium, size: 18))
                            .foregroundStyle(.white.opacity(0.92))

                        if !result.locationDetail.isEmpty {
                            Text(", \(result.locationDetail)")
                                .font(.klima(.book, size: 18))
                                .foregroundStyle(.white.opacity(0.54))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))

                TextField(
                    "",
                    text: $viewModel.searchText,
                    prompt: Text("Search for a city or airport").foregroundStyle(.white.opacity(0.78))
                )
                    .font(.klima(.book, size: 18))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .tint(.white)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        Task {
                            let added = await viewModel.addCityFromSearch()
                            if added {
                                onClose()
                            }
                        }
                    }
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.scheduleSearchSuggestions(for: newValue)
                    }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.clearSearch()
                        isSearchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.klimaWhite(0.10))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
            )

            Button {
                onClose()
            } label: {
                Circle()
                    .fill(Color.klimaWhite(0.10))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(Color.klimaBlack)
    }
}

private struct CurrentLocationWeatherCard: View {
    let location: CityListCurrentLocation
    let onSelect: () -> Void

    private var primaryTextColor: Color {
        location.isDaylight ? .black : .white
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(location.isDaylight ? 0.64 : 0.68)
    }

    private var tertiaryTextColor: Color {
        primaryTextColor.opacity(location.isDaylight ? 0.78 : 0.82)
    }

    private var emphasisTextColor: Color {
        primaryTextColor.opacity(location.isDaylight ? 0.84 : 0.92)
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .leading) {
                WeatherListCardBackground(isDaylight: location.isDaylight, rainIntensity: location.rainIntensity)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(.klima(.bold, size: 17))
                                .foregroundStyle(primaryTextColor)

                            Label {
                                Text("\(location.subtitle)  •  Home")
                            } icon: {
                                Image(systemName: "house.fill")
                            }
                            .font(.klima(.book, size: 11))
                            .foregroundStyle(secondaryTextColor)
                            .labelStyle(.titleAndIcon)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(location.temperature.temperatureString)
                            .font(.klima(.light, size: 31))
                            .foregroundStyle(primaryTextColor.opacity(location.isDaylight ? 0.94 : 0.98))
                            .kerning(-1.0)
                    }

                    HStack(alignment: .bottom) {
                        Text(location.rainIntensity == .none ? location.condition : "Rain for the next hour")
                            .font(.klima(.book, size: 13))
                            .foregroundStyle(tertiaryTextColor)
                            .lineLimit(1)

                        Spacer()

                        Text("H:\(location.highTemperature.temperatureString)  L:\(location.lowTemperature.temperatureString)")
                            .font(.klima(.demi, size: 12))
                            .foregroundStyle(emphasisTextColor)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 0.8)
        }
        .buttonStyle(.plain)
    }
}

private struct SavedCityWeatherCard: View {
    let city: SavedCityWeather
    let onSelect: () -> Void
    let remove: () -> Void

    private var primaryTextColor: Color {
        city.isDaylight ? .black : .white
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(city.isDaylight ? 0.64 : 0.68)
    }

    private var tertiaryTextColor: Color {
        primaryTextColor.opacity(city.isDaylight ? 0.78 : 0.82)
    }

    private var emphasisTextColor: Color {
        primaryTextColor.opacity(city.isDaylight ? 0.82 : 0.86)
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .leading) {
                WeatherListCardBackground(isDaylight: city.isDaylight, rainIntensity: city.rainIntensity)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name)
                                .font(.klima(.bold, size: 17))
                                .foregroundStyle(primaryTextColor)

                            Text(city.detailLine)
                                .font(.klima(.book, size: 11))
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(city.temperature.temperatureString)
                            .font(.klima(.light, size: 31))
                            .foregroundStyle(primaryTextColor.opacity(city.isDaylight ? 0.94 : 0.98))
                            .kerning(-1.0)
                    }

                    HStack(alignment: .bottom) {
                        Text(city.condition)
                            .font(.klima(.book, size: 13))
                            .foregroundStyle(tertiaryTextColor)
                            .lineLimit(1)

                        Spacer()

                        Text("H:\(city.highTemperature.temperatureString)  L:\(city.lowTemperature.temperatureString)")
                            .font(.klima(.demi, size: 12))
                            .foregroundStyle(emphasisTextColor)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 0.8)
        }
        .contextMenu {
            Button("Remove City", role: .destructive, action: remove)
        }
        .buttonStyle(.plain)
    }
}

private struct WeatherListCardBackground: View {
    let isDaylight: Bool
    let rainIntensity: RainIntensity

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.klimaWhite(isDaylight ? 0.06 : 0.04),
                    Color.clear,
                    Color.klimaBlack(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !isDaylight {
                StarField()
                    .opacity(rainIntensity == .none ? 0.16 : 0.06)
            }

            Circle()
                .fill(Color.klimaWhite(isDaylight ? 0.05 : 0.03))
                .frame(width: 132, height: 132)
                .blur(radius: 34)
                .offset(x: 116, y: -42)

            Ellipse()
                .fill(Color.klimaWhite(rainIntensity == .none ? 0.04 : 0.10))
                .frame(width: 188, height: 50)
                .blur(radius: 22)
                .offset(x: -28, y: -8)

            Ellipse()
                .fill(Color.klimaWhite(rainIntensity == .none ? 0.02 : 0.08))
                .frame(width: 240, height: 32)
                .blur(radius: 18)
                .offset(x: 12, y: 8)

            Ellipse()
                .fill(Color.klimaBlack(0.18))
                .frame(width: 250, height: 52)
                .blur(radius: 26)
                .offset(x: 34, y: -24)

            if rainIntensity != .none {
                RainStreaks(intensity: rainIntensity)
                    .opacity(0.30)
            }

            LinearGradient(
                colors: [
                    Color.klimaWhite(0.08),
                    Color.clear,
                    Color.klimaBlack(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientColors: [Color] {
        if isDaylight {
            return [
                Color.klimaCardDayTop,
                .klimaCardDayBottom
            ]
        }

        return [
            Color.klimaCardNightTop,
            .klimaCardNightBottom
        ]
    }
}

private struct StarField: View {
    private let stars: [CGPoint] = [
        CGPoint(x: 0.10, y: 0.18), CGPoint(x: 0.22, y: 0.30), CGPoint(x: 0.31, y: 0.16),
        CGPoint(x: 0.48, y: 0.26), CGPoint(x: 0.60, y: 0.14), CGPoint(x: 0.72, y: 0.22),
        CGPoint(x: 0.82, y: 0.12), CGPoint(x: 0.16, y: 0.54), CGPoint(x: 0.41, y: 0.48),
        CGPoint(x: 0.68, y: 0.52), CGPoint(x: 0.88, y: 0.42)
    ]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(stars.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(Color.klimaWhite(0.7))
                    .frame(width: 1.8, height: 1.8)
                    .position(x: geometry.size.width * point.x, y: geometry.size.height * point.y)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RainStreaks: View {
    let intensity: RainIntensity

    var body: some View {
        GeometryReader { geometry in
            let count: Int = switch intensity {
            case .none: 0
            case .light: 10
            case .medium: 16
            case .heavy: 24
            }

            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.klimaWhite(0.01), Color.klimaWhite(0.14), Color.klimaWhite(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1.0, height: index.isMultiple(of: 3) ? 28 : 20)
                    .rotationEffect(.degrees(7))
                    .position(
                        x: geometry.size.width * normalizedX(for: index, total: count),
                        y: geometry.size.height * normalizedY(for: index)
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func normalizedX(for index: Int, total: Int) -> CGFloat {
        CGFloat(index + 1) / CGFloat(total + 1)
    }

    private func normalizedY(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0.18, 0.34, 0.54, 0.28, 0.62, 0.42]
        return pattern[index % pattern.count]
    }
}

private struct CitySearchResult: Identifiable, Hashable {
    let storedCity: StoredCity

    var id: UUID { storedCity.id }
    var locationDetail: String { storedCity.locationDetail }
}

private actor CityLookupService {
    func search(query: String) async -> [CitySearchResult] {
        let completions = await CitySearchCompleter.completions(for: query)
        let uniqueCompletions = Array(NSOrderedSet(array: completions)) as? [MKLocalSearchCompletion] ?? completions
        let limitedCompletions = Array(uniqueCompletions.prefix(12))

        var results: [CitySearchResult] = []
        for completion in limitedCompletions {
            if let result = await resolve(completion: completion) {
                results.append(result)
            }
        }

        return results
    }

    func resolve(query: String) async -> StoredCity? {
        await search(query: query).first?.storedCity
    }

    private func resolve(completion: MKLocalSearchCompletion) async -> CitySearchResult? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            return cityResult(from: item, fallbackTitle: completion.title, fallbackSubtitle: completion.subtitle)
        } catch {
            return nil
        }
    }

    private func cityResult(from item: MKMapItem, fallbackTitle: String? = nil, fallbackSubtitle: String? = nil) -> CitySearchResult? {
        let coordinate = item.location.coordinate
        let addressComponents = locationComponents(
            from: item,
            fallbackTitle: fallbackTitle,
            fallbackSubtitle: fallbackSubtitle
        )

        let cityName = addressComponents.city ?? item.name
        guard let cityName, !cityName.isEmpty else { return nil }

        let region = addressComponents.region ?? ""
        let country = addressComponents.country ?? ""

        return CitySearchResult(
            storedCity: StoredCity(
                id: UUID(),
                name: cityName,
                region: region,
                country: country,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZoneIdentifier: item.timeZone?.identifier
            )
        )
    }

    private func locationComponents(
        from item: MKMapItem,
        fallbackTitle: String?,
        fallbackSubtitle: String?
    ) -> (city: String?, region: String?, country: String?) {
        let source = item.address?.fullAddress ?? item.address?.shortAddress ?? item.name ?? ""
        let directComponents = parseLocationComponents(source: source)
        if directComponents.city != nil {
            return directComponents
        }

        if let fallbackTitle, let fallbackSubtitle {
            return parseLocationComponents(title: fallbackTitle, subtitle: fallbackSubtitle)
        }

        return (item.name, nil, nil)
    }

    private func parseLocationComponents(source: String) -> (city: String?, region: String?, country: String?) {
        let components = source
            .replacingOccurrences(of: "\n", with: ", ")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !components.isEmpty else {
            return (nil, nil, nil)
        }

        let city = components.first.map { String($0) }
        let country = components.count >= 2 ? String(components[components.count - 1]) : nil
        let regionSource = components.count >= 2 ? String(components[components.count - 2]) : nil
        let region = regionSource?
            .split(separator: " ")
            .first
            .map(String.init) ?? regionSource

        return (
            city,
            region == city ? nil : region,
            country == city ? nil : country
        )
    }

    private func parseLocationComponents(title: String, subtitle: String) -> (city: String?, region: String?, country: String?) {
        let subtitleComponents = subtitle
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let region = subtitleComponents.first
        let country = subtitleComponents.count > 1 ? subtitleComponents.last : nil

        return (
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            region.map { String($0) },
            country.map { String($0) }
        )
    }
}

@MainActor
private final class CitySearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?

    static func completions(for query: String) async -> [MKLocalSearchCompletion] {
        let completer = CitySearchCompleter()
        return await completer.requestCompletions(for: query)
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.addressFilter = MKAddressFilter(including: [.locality, .subAdministrativeArea])
    }

    private func requestCompletions(for query: String) async -> [MKLocalSearchCompletion] {
        await withCheckedContinuation { continuation in
            self.continuation?.resume(returning: [])
            self.continuation = continuation
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        continuation?.resume(returning: completer.results)
        continuation = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        continuation?.resume(returning: [])
        continuation = nil
    }
}

private extension Font {
    static func klima(_ style: CityListFontStyle, size: CGFloat) -> Font {
        .custom(style.rawValue, size: size)
    }
}
