import SwiftUI

struct LocationsView: View {
    @Bindable private var viewModel: WeatherViewModel
    private let onDone: () -> Void

    init(viewModel: WeatherViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.searchQuery.isEmpty {
                    savedContent
                } else {
                    searchContent
                }
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .searchable(text: $viewModel.searchQuery)
        }
        .environment(\.locale, viewModel.locale)
        .task { await viewModel.loadSavedLocations() }
        .task(id: viewModel.searchQuery) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewModel.search(viewModel.searchQuery)
        }
    }

    @ViewBuilder
    private var savedContent: some View {
        Section {
            currentLocationRow
        }

        Section {
            if viewModel.savedLocations.isEmpty {
                ContentUnavailableView(
                    "No Saved Cities",
                    systemImage: "building.2",
                    description: Text("Search for a city to add it.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(viewModel.savedLocations.enumerated()), id: \.element.id) { index, city in
                    savedRow(city, index: index)
                }
                .onDelete { offsets in
                    let ids = offsets.map { viewModel.savedLocations[$0].id }
                    Task {
                        for id in ids { await viewModel.remove(id: id) }
                    }
                }
                .onMove { source, destination in
                    Task { await viewModel.move(fromOffsets: source, toOffset: destination) }
                }
            }
        }
    }

    private var currentLocationRow: some View {
        Button {
            select(.current)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label("Current Location", systemImage: "location.fill")
                    .font(.headline)
                if let name = viewModel.currentPlaceName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("locations.currentLocation")
    }

    private func savedRow(_ city: SavedLocation, index: Int) -> some View {
        Button {
            select(.saved(city))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(city.name)
                        .font(.headline)
                    Spacer(minLength: 8)
                    Text(localTime(of: city))
                        .font(.subheadline)
                }
                if let summary = summary(for: city) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .accessibilityActions {
            Button("Delete") {
                Task { await viewModel.remove(id: city.id) }
            }
            if index > 0 {
                Button("Move Up") {
                    Task { await viewModel.move(fromOffsets: [index], toOffset: index - 1) }
                }
            }
            if index < viewModel.savedLocations.count - 1 {
                Button("Move Down") {
                    Task { await viewModel.move(fromOffsets: [index], toOffset: index + 2) }
                }
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if viewModel.searchResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchQuery)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            ForEach(viewModel.searchResults) { place in
                Button {
                    Task { await viewModel.save(place) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.headline)
                        if let detail = detail(of: place) {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
        }
    }

    private func select(_ place: SelectedPlace) {
        Task { await viewModel.select(place) }
        onDone()
    }

    private func localTime(of city: SavedLocation) -> String {
        WeatherFormatter(locale: viewModel.locale, timeZone: TimeZone(identifier: city.timeZoneIdentifier)!)
            .clock(viewModel.currentDate)
    }

    private func summary(for city: SavedLocation) -> String? {
        guard let forecast = viewModel.savedForecasts[city.id],
              let summary = DaySummary.make(from: forecast, now: viewModel.currentDate)
        else { return nil }
        return WeatherFormatter(locale: viewModel.locale, timeZone: forecast.timeZone).summary(summary)
    }

    private func detail(of place: SavedLocation) -> String? {
        let parts = [place.region, place.country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
