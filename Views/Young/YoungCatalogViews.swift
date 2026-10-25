//
//  YoungCatalogViews.swift
//  Life@USTC
//
//  Public Second Classroom activity and organizer catalog.
//

import SwiftUI

@Observable
final class YoungEventsViewModel {
    let dateUnknown: Bool
    let pages: YoungEventsPageModel

    var events: [ServerYoungEvent] { pages.events }
    var unknownDateCount: Int { pages.unknownDateCount }
    var source: ServerYoungCatalogSource? { pages.source }
    var isLoading: Bool { pages.isLoading }
    var error: String? { pages.error }
    var filters: YoungBrowseFilters

    init(
        dateUnknown: Bool = false,
        filters: YoungBrowseFilters = .init(),
        client: ServerClient = .shared
    ) {
        self.dateUnknown = dateUnknown
        self.filters = filters
        pages = YoungEventsPageModel(client: client)
    }

    func load() async {
        let query = filters.query
        await pages.load(dateUnknown ? query.forUnknownDates() : query)
    }
}

struct YoungEventsListView: View {
    @State private var model: YoungEventsViewModel
    @State private var showingFilters = false

    init(dateUnknown: Bool = false, filters: YoungBrowseFilters = .init()) {
        _model = State(initialValue: YoungEventsViewModel(dateUnknown: dateUnknown, filters: filters))
    }

    var body: some View {
        List {
            Button { showingFilters = true } label: {
                HStack {
                    Text("Activity filters")
                    Spacer()
                    Text(model.filters.basis.title.localized).foregroundStyle(.secondary)
                    Image(systemName: model.filters.hasSelections
                          ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("young.filters")
            if let error = model.error, model.events.isEmpty && !model.isLoading {
                YoungErrorView(error: error) { Task { await model.load() } }
            } else {
                if let source = model.source {
                    YoungSourceFreshnessView(source: source)
                }
                YoungEventsLoadingStatus(model: model.pages)
                if model.events.isEmpty && model.pages.isComplete && model.unknownDateCount == 0 {
                    ContentUnavailableView {
                        Label(
                            model.dateUnknown
                                ? "No Activities with Unknown Dates".localized
                                : "No Activities".localized,
                            systemImage: "figure.run"
                        )
                    } description: {
                        Text(
                            model.dateUnknown
                                ? "Every matching activity has a date.".localized
                                : "There are no activities matching this filter.".localized
                        )
                    }
                }
                if !model.dateUnknown, model.unknownDateCount > 0 {
                    Section {
                        NavigationLink {
                            YoungEventsListView(
                                dateUnknown: true,
                                filters: model.filters
                            )
                        } label: {
                            Label(
                                YoungFormatting.countText(
                                    model.unknownDateCount,
                                    key: "%d activities have unknown dates"
                                ),
                                systemImage: "questionmark.circle"
                            )
                        }
                        .accessibilityIdentifier("young.unknownDates")
                    } footer: {
                        Text("These activities are retained even when the source has no date for the selected time basis.")
                    }
                }
                ForEach(model.events) { event in
                    NavigationLink {
                        YoungEventDetailView(youngId: event.youngId)
                    } label: {
                        YoungEventRow(event: event, basis: model.filters.basis)
                    }
                    .accessibilityIdentifier("young.event.\(event.youngId)")
                }
            }
        }
        .overlay {
            if model.isLoading && model.events.isEmpty { ProgressView() }
        }
        .navigationTitle(
            Text(
                model.dateUnknown
                    ? "Activities with unknown dates".localized
                    : "Activities".localized
            )
        )
        .searchable(text: $model.filters.search, prompt: "Search activities")
        .sheet(isPresented: $showingFilters) {
            YoungBrowseFiltersView(filters: model.filters, dateUnknown: model.dateUnknown) { model.filters = $0 }
        }
        .task(id: model.filters) { await model.load() }
        .refreshable { await model.load() }
    }
}

@Observable
final class YoungOrganizersViewModel {
    var organizers: [ServerYoungOrganizer] = []
    var isLoading = false
    var error: String?
    var search = ""

    private var generation = 0

    func load() async {
        generation += 1
        let requestGeneration = generation
        isLoading = true
        error = nil
        do {
            let value = try await ServerClient.shared.fetchYoungOrganizers(
                search: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : search.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard requestGeneration == generation, !Task.isCancelled else { return }
            organizers = value
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        guard requestGeneration == generation else { return }
        isLoading = false
    }
}

struct YoungOrganizersListView: View {
    @State private var model = YoungOrganizersViewModel()

    var body: some View {
        Group {
            if let error = model.error, model.organizers.isEmpty && !model.isLoading {
                YoungErrorView(error: error) { Task { await model.load() } }
            } else if model.organizers.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Organizers",
                    systemImage: "person.3",
                    description: Text("No organizers were found.")
                )
            } else {
                List(model.organizers) { organizer in
                    NavigationLink {
                        YoungOrganizerDetailView(organizerId: organizer.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(organizer.name)
                                .font(.headline)
                            HStack(spacing: 12) {
                                if let count = organizer.totalCount {
                                    Text(YoungFormatting.countText(count, key: "%d total"))
                                }
                                if let count = organizer.activeCount {
                                    Text(YoungFormatting.countText(count, key: "%d in source signup list"))
                                }
                                if let count = organizer.upcomingCount {
                                    Text(YoungFormatting.countText(count, key: "%d upcoming"))
                                }
                                if let count = organizer.historyCount {
                                    Text(YoungFormatting.countText(count, key: "%d past"))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("Organizers")
        .searchable(text: $model.search, prompt: "Search organizers")
        .task(id: model.search) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await model.load()
        }
        .refreshable { await model.load() }
    }
}
