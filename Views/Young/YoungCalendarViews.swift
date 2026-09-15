//
//  YoungCalendarViews.swift
//  Life@USTC
//
//  Public activity agenda and complete personal calendar views.
//

import SwiftUI

@Observable
private final class YoungActivityCalendarModel {
    var mode: YoungCalendarDisplayMode = .week
    var basis: YoungEventTimeBasis = .activity
    var referenceDate = Date()
    var events: [ServerYoungEvent] = []
    var unknownDateCount = 0
    var source: ServerYoungCatalogSource?
    var isLoading = false
    var error: String?

    private var generation = 0

    var requestID: String {
        "\(mode.rawValue)-\(basis.rawValue)-\(YoungCalendarDate.dateString(referenceDate))"
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let requestedMode = mode
        let requestedBasis = basis
        let requestedReferenceDate = referenceDate
        let range = YoungCalendarDate.range(for: requestedMode, date: requestedReferenceDate)
        isLoading = true
        error = nil
        events = []
        unknownDateCount = 0
        source = nil
        do {
            let page = try await ServerClient.shared.fetchYoungEventsPage(
                dateFrom: range.from,
                dateTo: range.to,
                timeBasis: requestedBasis
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

    func events(on date: Date) -> [ServerYoungEvent] {
        events
            .filter { $0.overlaps(day: date, basis: basis) }
            .sorted { lhs, rhs in
                let left = lhs.dateRange(for: basis).0 ?? lhs.dateRange(for: basis).1 ?? .distantFuture
                let right = rhs.dateRange(for: basis).0 ?? rhs.dateRange(for: basis).1 ?? .distantFuture
                return left == right ? lhs.name < rhs.name : left < right
            }
    }

    var weekDates: [Date] {
        let start = YoungCalendarDate.weekStart(referenceDate)
        return (0..<7).compactMap {
            YoungCalendarDate.calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    var monthGridDates: [Date] {
        let calendar = YoungCalendarDate.calendar
        let monthStart = YoungCalendarDate.monthStart(referenceDate)
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday + 5) % 7
        let cellCount = Int(ceil(Double(leadingDays + dayCount) / 7.0)) * 7
        guard let first = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) else {
            return []
        }
        return (0..<cellCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: first)
        }
    }
}

struct YoungActivityCalendarView: View {
    @State private var model = YoungActivityCalendarModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Calendar", selection: $model.mode) {
                ForEach(YoungCalendarDisplayMode.allCases) { mode in
                    Text(mode.title.localized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Picker("Time basis", selection: $model.basis) {
                ForEach(YoungEventTimeBasis.allCases) { basis in
                    Text(basis.title.localized).tag(basis)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            HStack {
                Button {
                    model.referenceDate = YoungCalendarDate.advance(
                        model.referenceDate,
                        mode: model.mode,
                        amount: -1
                    )
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Previous period")
                Spacer()
                Text(YoungFormatting.rangeTitle(for: model.mode, date: model.referenceDate))
                    .font(.headline)
                Spacer()
                Button {
                    model.referenceDate = YoungCalendarDate.advance(
                        model.referenceDate,
                        mode: model.mode
                    )
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Next period")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if let source = model.source {
                YoungSourceFreshnessView(source: source)
                    .padding(.bottom, 4)
            }

            if model.unknownDateCount > 0 {
                HStack {
                    NavigationLink {
                        YoungEventsListView(dateUnknown: true, basis: model.basis)
                    } label: {
                        Label(
                            YoungFormatting.countText(
                                model.unknownDateCount,
                                key: "%d activities have unknown dates"
                            ),
                            systemImage: "questionmark.circle"
                        )
                        .font(.caption)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            if let error = model.error, !model.isLoading {
                YoungErrorView(error: error, retry: { Task { await model.load() } })
            } else {
                calendarContent
                    .overlay {
                        if model.isLoading { ProgressView() }
                    }
            }
        }
        .navigationTitle("Activity Calendar")
        .task(id: model.requestID) { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch model.mode {
        case .day:
            List {
                YoungCalendarDayAgenda(
                    date: YoungCalendarDate.dayStart(model.referenceDate),
                    events: model.events(on: model.referenceDate),
                    basis: model.basis
                )
            }
        case .week:
            List {
                ForEach(model.weekDates, id: \.self) { date in
                    YoungCalendarDayAgenda(
                        date: date,
                        events: model.events(on: date),
                        basis: model.basis
                    )
                }
            }
        case .month:
            ScrollView {
                VStack(spacing: 0) {
                    monthGrid
                    Divider()
                        .padding(.vertical, 8)
                    LazyVStack(alignment: .leading, spacing: 0) {
                        YoungCalendarDayAgenda(
                            date: YoungCalendarDate.dayStart(model.referenceDate),
                            events: model.events(on: model.referenceDate),
                            basis: model.basis
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var monthGrid: some View {
        let calendar = YoungCalendarDate.calendar
        let monthStart = YoungCalendarDate.monthStart(model.referenceDate)
        return VStack(spacing: 6) {
            HStack {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day.localized)
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(model.monthGridDates, id: \.self) { date in
                    let isInMonth = calendar.component(.month, from: date) == calendar.component(.month, from: monthStart)
                    let isSelected = calendar.isDate(date, inSameDayAs: model.referenceDate)
                    let hasEvents = !model.events(on: date).isEmpty
                    Button {
                        model.referenceDate = date
                    } label: {
                        VStack(spacing: 3) {
                            Text(calendar.component(.day, from: date), format: .number)
                                .font(.subheadline)
                                .foregroundStyle(isInMonth ? .primary : .tertiary)
                            Circle()
                                .fill(hasEvents ? Color.accentColor : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}

@Observable
private final class WorkspaceCalendarModel {
    var mode: YoungCalendarDisplayMode = .week
    var referenceDate = Date()
    var events: [ServerPersonalCalendarEvent] = []
    var isLoading = false
    var error: String?

    private var generation = 0

    var requestID: String {
        "\(mode.rawValue)-\(YoungCalendarDate.dateString(referenceDate))"
    }

    func load() async {
        guard ServerClient.shared.isAuthenticated else { return }
        generation += 1
        let requestGeneration = generation
        let requestedMode = mode
        let requestedReferenceDate = referenceDate
        let range = YoungCalendarDate.range(for: requestedMode, date: requestedReferenceDate)
        isLoading = true
        error = nil
        events = []
        do {
            let value = try await ServerClient.shared.fetchPersonalCalendarEvents(
                dateFrom: range.from,
                dateTo: range.to
            )
            guard requestGeneration == generation, !Task.isCancelled else { return }
            events = value
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
        guard requestGeneration == generation else { return }
        isLoading = false
    }
}

struct WorkspaceCalendarView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = WorkspaceCalendarModel()

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                VStack(spacing: 0) {
                    Picker("Calendar", selection: $model.mode) {
                        ForEach(YoungCalendarDisplayMode.allCases) { mode in
                            Text(mode.title.localized).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    HStack {
                        Button {
                            model.referenceDate = YoungCalendarDate.advance(
                                model.referenceDate,
                                mode: model.mode,
                                amount: -1
                            )
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel("Previous period")
                        Spacer()
                        Text(YoungFormatting.rangeTitle(for: model.mode, date: model.referenceDate))
                            .font(.headline)
                        Spacer()
                        Button {
                            model.referenceDate = YoungCalendarDate.advance(
                                model.referenceDate,
                                mode: model.mode
                            )
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityLabel("Next period")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    if let error = model.error, !model.isLoading {
                        YoungErrorView(error: error, retry: { Task { await model.load() } }, reauthorize: true)
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
                        .overlay {
                            if model.isLoading { ProgressView() }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Calendar")
        .task(id: "\(model.requestID)-\(account.isAuthenticated)") { await model.load() }
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
                Text(event.title)
                    .font(.headline)
                Spacer()
                Text(eventTypeTitle(event.type).localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let at = event.at {
                Text(YoungFormatting.dateRange(at, event.endsAt))
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
}
