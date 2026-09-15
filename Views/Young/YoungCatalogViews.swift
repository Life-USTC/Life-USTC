//
//  YoungCatalogViews.swift
//  Life@USTC
//
//  Public Second Classroom activity and organizer catalog.
//

import SwiftUI

@Observable
private final class YoungEventsViewModel {
    let dateUnknown: Bool
    let organizerId: String?
    let basis: YoungEventTimeBasis

    var events: [ServerYoungEvent] = []
    var unknownDateCount = 0
    var source: ServerYoungCatalogSource?
    var isLoading = false
    var error: String?
    var search = ""
    var activeOnly = false

    private var generation = 0

    init(
        dateUnknown: Bool = false,
        organizerId: String? = nil,
        basis: YoungEventTimeBasis = .activity
    ) {
        self.dateUnknown = dateUnknown
        self.organizerId = organizerId
        self.basis = basis
    }

    var requestID: String {
        [
            dateUnknown ? "unknown" : "dated",
            organizerId ?? "all",
            basis.rawValue,
            activeOnly ? "active" : "all",
            search,
        ].joined(separator: "|")
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        isLoading = true
        error = nil
        events = []
        unknownDateCount = 0
        source = nil
        do {
            let page = try await ServerClient.shared.fetchYoungEventsPage(
                dateUnknown: dateUnknown ? true : nil,
                active: activeOnly ? true : nil,
                search: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : search.trimmingCharacters(in: .whitespacesAndNewlines),
                organizerId: organizerId,
                timeBasis: basis
            )
            guard requestGeneration == generation, !Task.isCancelled else { return }
            events = page.data
            unknownDateCount = page.unknownDateCount
            source = page.source
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        guard requestGeneration == generation else { return }
        isLoading = false
    }
}

struct YoungEventsListView: View {
    private let organizerId: String?
    @State private var model: YoungEventsViewModel

    init(
        organizerId: String? = nil,
        dateUnknown: Bool = false,
        basis: YoungEventTimeBasis = .activity
    ) {
        self.organizerId = organizerId
        _model = State(
            initialValue: YoungEventsViewModel(
                dateUnknown: dateUnknown,
                organizerId: organizerId,
                basis: basis
            )
        )
    }

    var body: some View {
        Group {
            if let error = model.error, model.events.isEmpty && !model.isLoading {
                YoungErrorView(error: error) { Task { await model.load() } }
            } else if model.events.isEmpty && !model.isLoading && model.unknownDateCount == 0 && model.source == nil {
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
            } else {
                List {
                    if let source = model.source {
                        YoungSourceFreshnessView(source: source)
                    }
                    if !model.dateUnknown, model.unknownDateCount > 0 {
                        Section {
                            NavigationLink {
                                YoungEventsListView(
                                    organizerId: organizerId,
                                    dateUnknown: true,
                                    basis: model.basis
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
                        } footer: {
                            Text("These activities are retained even when the source has no date for the selected time basis.")
                        }
                    }
                    ForEach(model.events) { event in
                        NavigationLink {
                            YoungEventDetailView(youngId: event.youngId)
                        } label: {
                            YoungEventRow(event: event, basis: model.basis)
                        }
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle(
            Text(
                model.dateUnknown
                    ? "Activities with unknown dates".localized
                    : "Activities".localized
            )
        )
        .searchable(text: $model.search, prompt: "Search activities")
        .toolbar {
            if !model.dateUnknown {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.activeOnly.toggle()
                    } label: {
                        Label(
                            model.activeOnly ? "All Activities" : "Open Signups",
                            systemImage: model.activeOnly
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
        }
        .task(id: model.requestID) { await model.load() }
        .refreshable { await model.load() }
    }
}

@Observable
private final class YoungOrganizersViewModel {
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
                                    Text(YoungFormatting.countText(count, key: "%d open"))
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
