//
//  YoungDetailViews.swift
//  Life@USTC
//
//  Public Second Classroom activity and organizer details.
//

import SwiftUI

struct YoungEventDetailView: View {
    let youngId: String

    @State private var event: ServerYoungEvent?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if let error, event == nil && !isLoading {
                YoungErrorView(error: error) { Task { await load() } }
            } else if let event {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            if let imageURL = event.imageUrl, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(.quaternary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            Text(event.name)
                                .font(.title2.bold())
                            if let category = event.category, !category.isEmpty {
                                Text(category)
                                    .foregroundStyle(.secondary)
                            }
                            if event.sourceMissing == true {
                                Label(
                                    "The source no longer lists this activity; retained for discussion and history.",
                                    systemImage: "clock.badge.exclamationmark"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            } else if let lastSeenAt = event.lastSeenAt {
                                HStack(spacing: 6) {
                                    Label("Catalog freshness", systemImage: "clock")
                                    Text(lastSeenAt, style: .relative)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        detailFields(event)
                    }

                    if let organizerId = event.organizerId, let organizer = event.organizer {
                        Section("Organizer") {
                            NavigationLink {
                                YoungOrganizerDetailView(organizerId: organizerId)
                            } label: {
                                Label(organizer, systemImage: "person.2")
                            }
                        }
                    }

                    Section("Reminder and calendar") {
                        YoungEventSubscriptionPanel(youngId: event.youngId)
                    }

                    Section("Registration") {
                        Text("Registration is completed on the official Young website.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let url = event.officialSignupURL {
                            Link(destination: url) {
                                Label("Open official signup", systemImage: "arrow.up.right.square")
                            }
                        }
                    }

                    Section("Comments") {
                        CommentListView(
                            viewModel: CommentListViewModel(
                                targetType: "young-event",
                                youngId: event.youngId
                            )
                        )
                        .frame(minHeight: 260)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(Text(event?.name ?? "Activity"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: youngId) { await load() }
    }

    @ViewBuilder
    private func detailFields(_ event: ServerYoungEvent) -> some View {
        let activityRange = event.dateRange(for: .activity)
        if activityRange.0 != nil || activityRange.1 != nil {
            LabeledContent("Activity time", value: YoungFormatting.dateRange(activityRange.0, activityRange.1, includeYear: true))
        }
        let registrationRange = event.dateRange(for: .registration)
        if registrationRange.0 != nil || registrationRange.1 != nil {
            LabeledContent("Signup window", value: YoungFormatting.dateRange(registrationRange.0, registrationRange.1, includeYear: true))
        }
        if let location = event.location, !location.isEmpty {
            LabeledContent("Location", value: location)
        }
        if let department = event.department, !department.isEmpty {
            LabeledContent("Department", value: department)
        }
        if let hours = event.hours {
            LabeledContent("Hours", value: String(format: "%.1f", hours))
        }
        if let capacity = event.capacity {
            LabeledContent("Capacity", value: "\(event.appliedCount ?? 0) / \(capacity)")
        }
        if let status = event.status, !status.isEmpty {
            LabeledContent("Status", value: status)
        }
        if let status = event.registrationStatus, !status.isEmpty {
            LabeledContent("Signup status", value: status)
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        event = nil
        do {
            event = try await ServerClient.shared.fetchYoungEvent(youngId: youngId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

@Observable
private final class YoungOrganizerDetailModel {
    var organizer: ServerYoungOrganizer?
    var events: [ServerYoungEvent] = []
    var unknownDateCount = 0
    var source: ServerYoungCatalogSource?
    var isLoading = false
    var error: String?

    private var generation = 0

    func load(id: String) async {
        generation += 1
        let requestGeneration = generation
        isLoading = true
        error = nil
        do {
            async let organizerRequest = ServerClient.shared.fetchYoungOrganizer(organizerId: id)
            async let eventsRequest = ServerClient.shared.fetchYoungEventsPage(organizerId: id)
            let organizer = try await organizerRequest
            let page = try await eventsRequest
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.organizer = organizer
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

struct YoungOrganizerDetailView: View {
    let organizerId: String
    @State private var model = YoungOrganizerDetailModel()

    var body: some View {
        Group {
            if let error = model.error, model.organizer == nil && !model.isLoading {
                YoungErrorView(error: error) { Task { await model.load(id: organizerId) } }
            } else if let organizer = model.organizer {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(organizer.name)
                                .font(.title2.bold())
                            if organizer.normalizedName != organizer.name {
                                Text(organizer.normalizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 14) {
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
                            if let source = model.source {
                                YoungSourceFreshnessView(source: source)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Organizer updates") {
                        YoungOrganizerFollowPanel(organizerId: organizer.id)
                    }

                    if model.unknownDateCount > 0 {
                        Section {
                            NavigationLink {
                                YoungEventsListView(
                                    organizerId: organizer.id,
                                    dateUnknown: true,
                                    basis: .activity
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
                            Text("Open activities with no date for the activity time basis.")
                        }
                    }

                    eventSection("Open activities", events: model.events.filter(\.isActive))
                    eventSection(
                        "Upcoming activities",
                        events: model.events.filter {
                            !$0.isActive && $0.startAt != nil && ($0.startAt ?? .distantPast) >= Date()
                        }
                    )
                    eventSection(
                        "Past activities",
                        events: model.events.filter {
                            !$0.isActive && $0.startAt != nil && ($0.startAt ?? .distantFuture) < Date()
                        }
                    )
                    eventSection(
                        "Date unavailable",
                        events: model.events.filter { !$0.isActive && $0.startAt == nil }
                    )
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(Text(model.organizer?.name ?? "Organizer"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: organizerId) { await model.load(id: organizerId) }
        .refreshable { await model.load(id: organizerId) }
    }

    @ViewBuilder
    private func eventSection(_ title: String, events: [ServerYoungEvent]) -> some View {
        if !events.isEmpty {
            Section(title) {
                ForEach(events) { event in
                    NavigationLink {
                        YoungEventDetailView(youngId: event.youngId)
                    } label: {
                        YoungEventRow(event: event, basis: .activity)
                    }
                }
            }
        }
    }
}
