//
//  YoungCommunityViews.swift
//  Life@USTC
//
//  Native Second Classroom catalog, calendar, workspace, and subscription UI.
//

import Foundation
import SwiftUI

// MARK: - Shared state views

private struct YoungErrorView: View {
    let error: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Unable to load")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
    }
}

struct YoungLoginRequiredView: View {
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.lock")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Sign in to use workspace features")
                .font(.headline)
            Text("Subscriptions, your personal calendar, and notifications are linked to your Life@USTC account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    isLoading = true
                    error = nil
                    do {
                        try await ServerAuth.shared.login()
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}

private struct YoungEventRow: View {
    let event: ServerYoungEvent
    let basis: YoungEventTimeBasis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name)
                        .font(.headline)
                    if let organizer = event.organizer, !organizer.isEmpty {
                        Text(organizer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if event.sourceMissing == true {
                    Text("Source missing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if event.isActive {
                    Text("Open")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }

            let (start, end) = event.dateRange(for: basis)
            Text(formatRange(start, end))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let category = event.category, !category.isEmpty {
                    Text(category)
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatRange(_ start: Date?, _ end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.calendar = YoungCalendarDate.calendar
        formatter.timeZone = YoungCalendarDate.shanghai
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        switch (start, end) {
        case let (start?, end?): return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        case let (start?, nil): return formatter.string(from: start)
        case let (nil, end?): return "Ends \(formatter.string(from: end))"
        case (nil, nil): return "Time unavailable"
        }
    }
}

// MARK: - Public catalog landing

struct YoungCommunityView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    YoungEventsListView()
                } label: {
                    Label("Activities", systemImage: "figure.run")
                }
                NavigationLink {
                    YoungActivityCalendarView()
                } label: {
                    Label("Activity Calendar", systemImage: "calendar")
                }
                NavigationLink {
                    YoungOrganizersListView()
                } label: {
                    Label("Organizers", systemImage: "person.3")
                }
            } header: {
                Text("Second Classroom")
            } footer: {
                Text("Browse activities from young.ustc.edu.cn. Registration is completed on the official site.")
            }

            Section("Workspace") {
                NavigationLink {
                    WorkspaceCalendarView()
                } label: {
                    Label("My Calendar", systemImage: "calendar.badge.clock")
                }
                NavigationLink {
                    YoungNotificationsView()
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }
        }
        .navigationTitle("Second Classroom")
    }
}

// MARK: - Public events

@Observable
private final class YoungEventsViewModel {
    var events: [ServerYoungEvent] = []
    var isLoading = false
    var error: String?
    var search = ""
    var activeOnly = false

    func load() async {
        isLoading = true
        error = nil
        do {
            events = try await ServerClient.shared.fetchYoungEvents(
                active: activeOnly ? true : nil,
                search: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : search.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct YoungEventsListView: View {
    @State private var model = YoungEventsViewModel()

    var body: some View {
        Group {
            if let error = model.error, model.events.isEmpty && !model.isLoading {
                YoungErrorView(error: error) { Task { await model.load() } }
            } else if model.events.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Activities",
                    systemImage: "figure.run",
                    description: Text("There are no activities matching this filter.")
                )
            } else {
                List(model.events) { event in
                    NavigationLink {
                        YoungEventDetailView(youngId: event.youngId)
                    } label: {
                        YoungEventRow(event: event, basis: .activity)
                    }
                }
                .overlay {
                    if model.isLoading { ProgressView() }
                }
            }
        }
        .navigationTitle("Activities")
        .searchable(text: $model.search, prompt: "Search activities")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.activeOnly.toggle()
                    Task { await model.load() }
                } label: {
                    Label(
                        model.activeOnly ? "All Activities" : "Open Signups",
                        systemImage: model.activeOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                    )
                }
            }
        }
        .task { await model.load() }
        .task(id: model.search) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await model.load()
        }
        .refreshable { await model.load() }
    }
}

// MARK: - Organizer catalog

@Observable
private final class YoungOrganizersViewModel {
    var organizers: [ServerYoungOrganizer] = []
    var isLoading = false
    var error: String?
    var search = ""

    func load() async {
        isLoading = true
        error = nil
        do {
            organizers = try await ServerClient.shared.fetchYoungOrganizers(
                search: search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : search.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            self.error = error.localizedDescription
        }
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
                                    Text("\(count) total")
                                }
                                if let count = organizer.activeCount {
                                    Text("\(count) open")
                                }
                                if let count = organizer.upcomingCount {
                                    Text("\(count) upcoming")
                                }
                                if let count = organizer.historyCount {
                                    Text("\(count) past")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .overlay { if model.isLoading { ProgressView() } }
            }
        }
        .navigationTitle("Organizers")
        .searchable(text: $model.search, prompt: "Search organizers")
        .task { await model.load() }
        .task(id: model.search) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await model.load()
        }
        .refreshable { await model.load() }
    }
}

// MARK: - Event detail and subscriptions

struct YoungEventDetailView: View {
    let youngId: String

    @State private var event: ServerYoungEvent?
    @State private var subscription: ServerYoungEventSubscriptionState?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        Group {
            if let error, event == nil && !isLoading {
                YoungErrorView(error: error) { Task { await load() } }
            } else if let event {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.name)
                                .font(.title2.bold())
                            if let category = event.category { Text(category).foregroundStyle(.secondary) }
                            if event.sourceMissing == true {
                                Label("The source no longer lists this activity; retained for discussion and history.", systemImage: "clock.badge.exclamationmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let lastSeenAt = event.lastSeenAt {
                                Text("Catalog checked \(lastSeenAt, style: .relative) ago")
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

                    if ServerClient.shared.isAuthenticated {
                        Section("Reminder and calendar") {
                            Toggle("Add activity to my calendar", isOn: subscribedBinding)
                                .disabled(isSaving || subscription == nil)
                            if subscription?.subscribed == true {
                                Toggle("Signup reminder", isOn: remindSignupBinding)
                                    .disabled(isSaving)
                                Toggle("Deadline reminder", isOn: remindDeadlineBinding)
                                    .disabled(isSaving)
                                Toggle("Start reminder", isOn: remindStartBinding)
                                    .disabled(isSaving)
                                Text("This is a personal reminder and calendar subscription. It does not register attendance.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Section("Reminder and calendar") {
                            YoungLoginRequiredView()
                        }
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
        .navigationTitle(event?.name ?? "Activity")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func detailFields(_ event: ServerYoungEvent) -> some View {
        let activityRange = event.dateRange(for: .activity)
        if activityRange.0 != nil || activityRange.1 != nil {
            LabeledContent("Activity time", value: formatRange(activityRange.0, activityRange.1))
        }
        let registrationRange = event.dateRange(for: .registration)
        if registrationRange.0 != nil || registrationRange.1 != nil {
            LabeledContent("Signup window", value: formatRange(registrationRange.0, registrationRange.1))
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

    private func formatRange(_ start: Date?, _ end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.calendar = YoungCalendarDate.calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = YoungCalendarDate.shanghai
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        switch (start, end) {
        case let (start?, end?): return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        case let (start?, nil): return formatter.string(from: start)
        case let (nil, end?): return "Until \(formatter.string(from: end))"
        case (nil, nil): return "Unknown"
        }
    }

    private var subscribedBinding: Binding<Bool> {
        Binding(
            get: { subscription?.subscribed ?? false },
            set: { value in Task { await updateSubscription(subscribed: value) } }
        )
    }

    private var remindSignupBinding: Binding<Bool> {
        Binding(
            get: { subscription?.remindSignup ?? false },
            set: { value in Task { await updateSubscription(remindSignup: value) } }
        )
    }

    private var remindDeadlineBinding: Binding<Bool> {
        Binding(
            get: { subscription?.remindDeadline ?? false },
            set: { value in Task { await updateSubscription(remindDeadline: value) } }
        )
    }

    private var remindStartBinding: Binding<Bool> {
        Binding(
            get: { subscription?.remindStart ?? false },
            set: { value in Task { await updateSubscription(remindStart: value) } }
        )
    }

    private func load() async {
        isLoading = true
        error = nil
        do {
            event = try await ServerClient.shared.fetchYoungEvent(youngId: youngId)
            if ServerClient.shared.isAuthenticated {
                subscription = try await ServerClient.shared.fetchYoungEventSubscription(youngId: youngId)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func updateSubscription(
        subscribed: Bool? = nil,
        remindSignup: Bool? = nil,
        remindDeadline: Bool? = nil,
        remindStart: Bool? = nil
    ) async {
        guard let current = subscription else { return }
        isSaving = true
        error = nil
        do {
            subscription = try await ServerClient.shared.updateYoungEventSubscription(
                youngId: youngId,
                subscribed: subscribed ?? current.subscribed,
                remindSignup: remindSignup ?? current.remindSignup,
                remindDeadline: remindDeadline ?? current.remindDeadline,
                remindStart: remindStart ?? current.remindStart
            )
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Organizer detail and following

@Observable
private final class YoungOrganizerDetailModel {
    var organizer: ServerYoungOrganizer?
    var events: [ServerYoungEvent] = []
    var subscription: ServerYoungOrganizerSubscriptionState?
    var isLoading = false
    var error: String?

    func load(id: String) async {
        isLoading = true
        error = nil
        do {
            async let organizerRequest = ServerClient.shared.fetchYoungOrganizer(organizerId: id)
            async let eventsRequest = ServerClient.shared.fetchYoungEvents(organizerId: id)
            organizer = try await organizerRequest
            events = try await eventsRequest
            if ServerClient.shared.isAuthenticated {
                subscription = try await ServerClient.shared.fetchYoungOrganizerSubscription(organizerId: id)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct YoungOrganizerDetailView: View {
    let organizerId: String
    @State private var model = YoungOrganizerDetailModel()
    @State private var isSaving = false

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
                                if let count = organizer.totalCount { Text("\(count) total") }
                                if let count = organizer.activeCount { Text("\(count) open") }
                                if let count = organizer.upcomingCount { Text("\(count) upcoming") }
                                if let count = organizer.historyCount { Text("\(count) past") }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if ServerClient.shared.isAuthenticated {
                        Section("Organizer updates") {
                            Toggle("Follow organizer", isOn: followBinding)
                                .disabled(isSaving || model.subscription == nil)
                            Text("Following this organizer does not subscribe you to its activities.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Organizer updates") { YoungLoginRequiredView() }
                    }

                    eventSection("Open activities", events: model.events.filter(\.isActive))
                    eventSection(
                        "Upcoming activities",
                        events: model.events.filter { !$0.isActive && ($0.startAt ?? .distantPast) >= Date() }
                    )
                    eventSection(
                        "Past activities",
                        events: model.events.filter { !$0.isActive && ($0.startAt ?? .distantFuture) < Date() }
                    )
                    eventSection(
                        "Date unavailable",
                        events: model.events.filter { !$0.isActive && $0.startAt == nil }
                    )
                }
                .overlay { if model.isLoading { ProgressView() } }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model.organizer?.name ?? "Organizer")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(id: organizerId) }
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

    private var followBinding: Binding<Bool> {
        Binding(
            get: { model.subscription?.subscribed ?? false },
            set: { value in
                Task {
                    guard model.subscription != nil else { return }
                    isSaving = true
                    do {
                        model.subscription = try await ServerClient.shared.updateYoungOrganizerSubscription(
                            organizerId: organizerId,
                            subscribed: value
                        )
                    } catch {
                        model.error = error.localizedDescription
                    }
                    isSaving = false
                }
            }
        )
    }
}

// MARK: - Public activity calendar

@Observable
private final class YoungActivityCalendarModel {
    var mode: YoungCalendarDisplayMode = .week
    var basis: YoungEventTimeBasis = .activity
    var referenceDate = Date()
    var events: [ServerYoungEvent] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        let range = YoungCalendarDate.range(for: mode, date: referenceDate)
        do {
            events = try await ServerClient.shared.fetchYoungEvents(
                dateFrom: range.from,
                dateTo: range.to,
                timeBasis: basis
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct YoungActivityCalendarView: View {
    @State private var model = YoungActivityCalendarModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Calendar", selection: $model.mode) {
                ForEach(YoungCalendarDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Picker("Time basis", selection: $model.basis) {
                ForEach(YoungEventTimeBasis.allCases) { basis in
                    Text(basis.title).tag(basis)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            HStack {
                Button { model.referenceDate = YoungCalendarDate.advance(model.referenceDate, mode: model.mode, amount: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(rangeTitle)
                    .font(.headline)
                Spacer()
                Button { model.referenceDate = YoungCalendarDate.advance(model.referenceDate, mode: model.mode) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Group {
                if let error = model.error, model.events.isEmpty && !model.isLoading {
                    YoungErrorView(error: error) { Task { await model.load() } }
                } else if model.events.isEmpty && !model.isLoading {
                    ContentUnavailableView(
                        "No Activities",
                        systemImage: "calendar",
                        description: Text("No activities overlap this period.")
                    )
                } else {
                    List(model.events) { event in
                        NavigationLink {
                            YoungEventDetailView(youngId: event.youngId)
                        } label: {
                            YoungEventRow(event: event, basis: model.basis)
                        }
                    }
                    .overlay { if model.isLoading { ProgressView() } }
                }
            }
        }
        .navigationTitle("Activity Calendar")
        .task(id: calendarLoadID) { await model.load() }
        .refreshable { await model.load() }
    }

    private var calendarLoadID: String {
        "\(model.mode.rawValue)-\(model.basis.rawValue)-\(YoungCalendarDate.dateString(model.referenceDate))"
    }

    private var rangeTitle: String {
        let range = YoungCalendarDate.range(for: model.mode, date: model.referenceDate)
        return range.from == range.to ? range.from : "\(range.from) – \(range.to)"
    }
}

// MARK: - Complete authenticated personal calendar

@Observable
private final class WorkspaceCalendarModel {
    var mode: YoungCalendarDisplayMode = .week
    var referenceDate = Date()
    var events: [ServerPersonalCalendarEvent] = []
    var isLoading = false
    var error: String?

    func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        isLoading = true
        error = nil
        let range = YoungCalendarDate.range(for: mode, date: referenceDate)
        do {
            events = try await ServerClient.shared.fetchPersonalCalendarEvents(
                dateFrom: range.from,
                dateTo: range.to
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct WorkspaceCalendarView: View {
    @State private var model = WorkspaceCalendarModel()

    var body: some View {
        Group {
            if !ServerClient.shared.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                VStack(spacing: 0) {
                    Picker("Calendar", selection: $model.mode) {
                        ForEach(YoungCalendarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    HStack {
                        Button { model.referenceDate = YoungCalendarDate.advance(model.referenceDate, mode: model.mode, amount: -1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(rangeTitle)
                            .font(.headline)
                        Spacer()
                        Button { model.referenceDate = YoungCalendarDate.advance(model.referenceDate, mode: model.mode) } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    if let error = model.error, model.events.isEmpty && !model.isLoading {
                        YoungErrorView(error: error) { Task { await model.load() } }
                    } else if model.events.isEmpty && !model.isLoading {
                        ContentUnavailableView(
                            "Calendar Empty",
                            systemImage: "calendar",
                            description: Text("No personal events overlap this period.")
                        )
                    } else {
                        List(model.events) { event in
                            personalEventRow(event)
                        }
                        .overlay { if model.isLoading { ProgressView() } }
                    }
                }
            }
        }
        .navigationTitle("My Calendar")
        .task(id: calendarLoadID) { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func personalEventRow(_ event: ServerPersonalCalendarEvent) -> some View {
        if event.type == "young_event", let youngId = event.youngId {
            NavigationLink {
                YoungEventDetailView(youngId: youngId)
            } label: {
                personalEventLabel(event)
            }
        } else {
            personalEventLabel(event)
        }
    }

    private func personalEventLabel(_ event: ServerPersonalCalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title).font(.headline)
                Spacer()
                Text(eventTypeTitle(event.type))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let at = event.at {
                HStack(spacing: 4) {
                    Text(at, style: .time)
                    if let endsAt = event.endsAt {
                        Text("–")
                        Text(endsAt, style: .time)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func eventTypeTitle(_ type: String) -> String {
        switch type {
        case "young_event": "Activity"
        case "schedule": "Course"
        case "exam": "Exam"
        case "homework_due": "Homework"
        case "todo_due": "Todo"
        default: type
        }
    }

    private var calendarLoadID: String {
        "\(model.mode.rawValue)-\(YoungCalendarDate.dateString(model.referenceDate))"
    }

    private var rangeTitle: String {
        let range = YoungCalendarDate.range(for: model.mode, date: model.referenceDate)
        return range.from == range.to ? range.from : "\(range.from) – \(range.to)"
    }
}

// MARK: - Personal notifications

@Observable
private final class YoungNotificationsModel {
    var notifications: [ServerYoungNotification] = []
    var isLoading = false
    var error: String?

    func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        isLoading = true
        error = nil
        do {
            notifications = try await ServerClient.shared.fetchYoungNotifications()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markRead(_ notification: ServerYoungNotification) async {
        guard !notification.isRead else { return }
        do {
            _ = try await ServerClient.shared.markYoungNotificationRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                let current = notifications[index]
                notifications[index] = ServerYoungNotification(
                    id: current.id,
                    youngId: current.youngId,
                    organizerId: current.organizerId,
                    kind: current.kind,
                    title: current.title,
                    body: current.body,
                    createdAt: current.createdAt,
                    readAt: Date(),
                    expiresAt: current.expiresAt
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct YoungNotificationsView: View {
    @State private var model = YoungNotificationsModel()

    var body: some View {
        Group {
            if !ServerClient.shared.isAuthenticated {
                YoungLoginRequiredView()
            } else if let error = model.error, model.notifications.isEmpty && !model.isLoading {
                YoungErrorView(error: error) { Task { await model.load() } }
            } else if model.notifications.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell",
                    description: Text("You are up to date.")
                )
            } else {
                List(model.notifications) { notification in
                    notificationRow(notification)
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await model.markRead(notification) } }
                }
                .overlay { if model.isLoading { ProgressView() } }
            }
        }
        .navigationTitle("Notifications")
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func notificationRow(_ notification: ServerYoungNotification) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(notification.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.headline)
                Text(notification.body)
                    .font(.subheadline)
                Text(notification.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let youngId = notification.youngId {
                    NavigationLink("Open activity") {
                        YoungEventDetailView(youngId: youngId)
                    }
                    .font(.caption)
                } else if let organizerId = notification.organizerId {
                    NavigationLink("Open organizer") {
                        YoungOrganizerDetailView(organizerId: organizerId)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
