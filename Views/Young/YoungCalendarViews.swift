//
//  YoungCalendarViews.swift
//  Life@USTC
//
//  Public activity calendar, with Sunday as the first day of the week.
//

import SwiftUI

enum YoungPublicCalendarDate {
    static func range(for mode: YoungCalendarDisplayMode, date: Date) -> ServerCalendarRange {
        let value = YoungCalendarDate.range(for: mode, date: date, firstWeekday: .sunday)
        return ServerCalendarRange(start: YoungCalendarDate.dateFormatter.date(from: value.from)!,
                                   end: YoungCalendarDate.dateFormatter.date(from: value.to)!)
    }

    static func monthGrid(for date: Date) -> [Date] {
        let calendar = YoungCalendarDate.calendar
        let start = YoungCalendarDate.monthStart(date)
        let dayCount = calendar.range(of: .day, in: .month, for: start)!.count
        let leadingDays = calendar.component(.weekday, from: start) - 1
        let cellCount = ((leadingDays + dayCount + 6) / 7) * 7
        let first = calendar.date(byAdding: .day, value: -leadingDays, to: start)!
        return (0..<cellCount).map { calendar.date(byAdding: .day, value: $0, to: first)! }
    }
}

@MainActor
@Observable
final class YoungActivityCalendarModel {
    var mode: YoungCalendarDisplayMode = .week
    var basis: YoungEventTimeBasis = .activity
    var referenceDate = Date()
    let pages: YoungEventsPageModel
    var events: [ServerYoungEvent] { pages.events }
    var unknownDateCount: Int { pages.unknownDateCount }
    var source: ServerYoungCatalogSource? { pages.source }
    var isLoading: Bool { pages.isLoading }
    var error: String? { pages.error }

    init(client: ServerClient = .shared) {
        pages = YoungEventsPageModel(client: client)
    }

    var requestID: String {
        "\(mode.rawValue)-\(basis.rawValue)-\(YoungCalendarDate.dateString(referenceDate))"
    }

    func load() async {
        let range = YoungPublicCalendarDate.range(for: mode, date: referenceDate)
        await pages.load(.init(dateFrom: YoungCalendarDate.dateString(range.start),
                               dateTo: YoungCalendarDate.dateString(range.end),
                               timeBasis: basis.queryValue))
    }

    func events(on date: Date) -> [ServerYoungEvent] {
        YoungFormatting.calendarEvents(events, on: date, mode: mode, basis: basis)
    }

    var weekDates: [Date] {
        YoungPublicCalendarDate.range(for: .week, date: referenceDate).days
    }

    var monthGridDates: [Date] {
        YoungPublicCalendarDate.monthGrid(for: referenceDate)
    }
}

struct YoungActivityCalendarView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = YoungActivityCalendarModel()
    @State private var personal = ServerWorkspaceCalendarModel()

    private var personalRequestID: String {
        let range = YoungPublicCalendarDate.range(for: model.mode, date: model.referenceDate)
        return "\(YoungCalendarDate.dateString(range.start))/\(YoungCalendarDate.dateString(range.end))"
    }

    private var conflicts: Set<String> {
        guard model.basis == .activity, personal.requestID == personalRequestID,
              !personal.isLoading, personal.error == nil else { return [] }
        return YoungFormatting.calendarConflicts(events: model.events, personal: personal.events)
    }

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
                let range = YoungPublicCalendarDate.range(for: model.mode, date: model.referenceDate)
                Text(model.mode == .day ? YoungCalendarDate.dateString(range.start)
                     : "\(YoungCalendarDate.dateString(range.start)) – \(YoungCalendarDate.dateString(range.end))")
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

            conflictStatus
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 6)

            if model.unknownDateCount > 0 {
                HStack {
                    NavigationLink {
                        YoungEventsListView(dateUnknown: true, filters: .init(basis: model.basis))
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

            if let error = model.error, model.events.isEmpty && !model.isLoading {
                YoungErrorView(error: error, retry: { Task { await model.load() } })
            } else {
                YoungEventsLoadingStatus(model: model.pages)
                    .padding(.horizontal)
                calendarContent
                    .overlay {
                        if model.isLoading && model.events.isEmpty { ProgressView() }
                    }
            }
        }
        .navigationTitle("Activity Calendar")
        .task(id: model.requestID) { await model.load() }
        .task(id: "\(model.requestID)-\(account.sessionRevision)") { await loadPersonalCalendar() }
        .refreshable {
            await model.load()
            await loadPersonalCalendar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await loadPersonalCalendar() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await loadPersonalCalendar() }
        }
    }

    @ViewBuilder
    private var conflictStatus: some View {
        if model.basis != .activity {
            Text("Switch to activity times to check calendar conflicts.")
        } else if !account.isAuthenticated {
            Text("Sign in to check conflicts with your personal calendar.")
        } else if personal.isLoading || personal.requestID != personalRequestID {
            Label("Checking calendar conflicts…", systemImage: "clock")
        } else if let error = personal.error {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar conflicts are unavailable.")
                Text(error)
                Button("Retry") { Task { await loadPersonalCalendar() } }
            }
        } else {
            Text("Conflicts use known occupied times from synced classes, exams, and subscribed activities. Confirm unknown times and broad activity windows separately; no warning does not establish availability or signup eligibility.")
        }
    }

    private func loadPersonalCalendar() async {
        guard model.basis == .activity else { return }
        personal.rangeOverride = YoungPublicCalendarDate.range(for: model.mode, date: model.referenceDate)
        await personal.load()
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch model.mode {
        case .day:
            List {
                YoungCalendarDayAgenda(
                    date: YoungCalendarDate.dayStart(model.referenceDate),
                    events: model.events(on: model.referenceDate),
                    basis: model.basis,
                    conflictingEventIDs: conflicts,
                    showsEmptyMessage: model.pages.isComplete
                )
            }
        case .week:
            List {
                if model.pages.isComplete && model.weekDates.allSatisfy({ model.events(on: $0).isEmpty }) {
                    Text("No activities").foregroundStyle(.secondary)
                }
                ForEach(model.weekDates, id: \.self) { date in
                    YoungCalendarDayAgenda(
                        date: date,
                        events: model.events(on: date),
                        basis: model.basis,
                        conflictingEventIDs: conflicts,
                        showsEmptyMessage: false
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
                            basis: model.basis,
                            conflictingEventIDs: conflicts,
                            showsEmptyMessage: model.pages.isComplete
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
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
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
