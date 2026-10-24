import SwiftUI

struct WorkspaceCalendarView: View {
    @Bindable private var account = ServerAccountStore.shared
    @Environment(\.locale) private var locale
    @State private var model = ServerWorkspaceCalendarModel()

    var body: some View {
        Group {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                VStack(spacing: 0) {
                    Picker("Calendar", selection: $model.mode) {
                        ForEach(model.modes) { mode in
                            Text(mode.title.localized).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("workspace_calendar_mode")
                    .padding()
                    if model.mode == .semester {
                        Picker("Semester", selection: $model.selectedSemesterID) {
                            ForEach(model.semesters) { semester in
                                Text(ServerCatalogDisplay.semesterName(semester)).tag(Optional(semester.id))
                            }
                        }
                        .accessibilityIdentifier("calendar_semester")
                    }
                    HStack {
                        Button { model.navigate(-1) } label: {
                            Label("Previous", systemImage: "chevron.left").labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Previous period")
                        Spacer()
                        Button("Today") { model.selectToday() }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("calendar_today")
                        Spacer()
                        Button { model.navigate(1) } label: {
                            Label("Next", systemImage: "chevron.right").labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Next period")
                    }
                    .padding(.horizontal)
                    if let range = model.range {
                        Text("\(YoungCalendarDate.dateString(range.start)) – \(YoungCalendarDate.dateString(range.end))")
                            .font(.subheadline)
                            .accessibilityIdentifier("calendar_range")
                            .padding(.bottom, 8)
                    }
                    if let error = model.error, !model.isLoading {
                        YoungErrorView(error: error, retry: { Task { await model.load() } }, reauthorize: true)
                    }
                    List {
                        if let error = model.semesterError {
                            Section {
                                Text(error).foregroundStyle(.secondary)
                                Button("Reload semester choices") { Task { await model.loadSemesters() } }
                            }
                        }
                        ForEach(model.agendaDays) { day in
                            Section {
                                if day.events.isEmpty {
                                    Text("No events").foregroundStyle(.secondary)
                                }
                                ForEach(day.events) { event in WorkspaceEventLink(event: event) }
                            } header: {
                                Text(dayTitle(day.date))
                                    .accessibilityIdentifier("calendar_day_\(day.id)")
                            }
                        }
                        let undated = model.events.filter { $0.at == nil }
                        if !undated.isEmpty {
                            Section("Date unavailable") {
                                ForEach(undated) { event in WorkspaceEventLink(event: event) }
                            }
                        }
                        if model.agendaDays.isEmpty && undated.isEmpty && !model.isLoading && model.error == nil {
                            ContentUnavailableView("Calendar Empty", systemImage: "calendar",
                                description: Text("No personal events overlap this period."))
                        }
                    }
                    .overlay { if model.isLoading { ProgressView() } }
                }
            }
        }
        .navigationTitle("My Calendar")
        .task(id: account.sessionRevision) { await model.loadSemesters() }
        .task(id: "\(model.requestID)-\(account.sessionRevision)") { await model.load() }
        .refreshable { await model.loadSemesters(); await model.load() }
        .toolbar {
            if account.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { ServerCalendarFeedView() } label: {
                        Label("Calendar subscription", systemImage: "calendar.badge.plus")
                    }
                    .accessibilityIdentifier("calendar_feed")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await model.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.loadSemesters(); await model.load() }
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = YoungCalendarDate.calendar
        formatter.timeZone = YoungCalendarDate.shanghai
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: date)
    }
}
