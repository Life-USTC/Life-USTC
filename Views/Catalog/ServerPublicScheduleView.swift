import SwiftUI

struct ServerPublicScheduleView: View {
    @Bindable private var account = ServerAccountStore.shared
    @Environment(\.locale) private var locale
    @State private var model = ServerPublicScheduleModel()
    @State private var showingFilters = false

    private var apiLocale: String { locale.language.languageCode?.identifier == "en" ? "en-us" : "zh-cn" }

    var body: some View {
        List {
            if !model.schedules.isEmpty {
                Text("\(model.total) results").foregroundStyle(.secondary)
            }
            ForEach(model.schedules) { schedule in
                Section {
                    if let section = schedule.section {
                        NavigationLink {
                            ServerSectionDetailView(jwId: section.jwId)
                        } label: {
                            scheduleLabel(schedule)
                        }
                        .accessibilityIdentifier("public_schedule_\(schedule.id)_section")
                    } else {
                        scheduleLabel(schedule)
                    }
                    ForEach(schedule.teachers ?? []) { teacher in
                        NavigationLink {
                            ServerTeacherDetailView(id: teacher.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(ServerCatalogDisplay.name(teacher.nameCn, teacher.nameEn), systemImage: "person")
                                if let code = teacher.code { Text(code).font(.caption).foregroundStyle(.secondary) }
                                if let participation = schedule.teacherParticipations?.first(where: { $0.id == teacher.id }) {
                                    if let periods = participation.periods {
                                        Text(String(format: "Teaching periods: %@".localized, periods.formatted()))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let exerciseClass = participation.exerciseClass {
                                        Text(exerciseClass ? String(localized: "Exercise class") : String(localized: "Not an exercise class"))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("public_schedule_\(schedule.id)_teacher_\(teacher.id)")
                    }
                }
            }
            if model.schedules.isEmpty && !model.isLoading && model.error == nil {
                ContentUnavailableView("No published schedule", systemImage: "calendar",
                                       description: Text("No schedules match these filters."))
            }
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await model.load(append: !model.schedules.isEmpty, locale: apiLocale) }
                    }
                    .accessibilityIdentifier("public_schedule_retry")
                }
            }
            if model.isLoading {
                ProgressView("Loading schedules…")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("public_schedule_loading")
            } else if model.hasMore && model.error == nil {
                Button("Load more") { Task { await model.load(append: true, locale: apiLocale) } }
                    .accessibilityIdentifier("public_schedule_load_more")
            }
            if model.reachedPageLimit {
                Text("Narrow the filters to see more schedules.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Public schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { showingFilters = true } label: {
                Label("Filter schedules", systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("public_schedule_filters")
        }
        .sheet(isPresented: $showingFilters) {
            ServerPublicScheduleFiltersView(filters: model.filters) { filters in
                Task { await model.apply(filters, locale: apiLocale) }
            }
        }
        .task(id: "\(account.sessionRevision)-\(apiLocale)") { await model.load(locale: apiLocale) }
        .refreshable { await model.load(locale: apiLocale) }
    }

    private func scheduleLabel(_ schedule: ServerScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let course = schedule.section?.course {
                Text(ServerCatalogDisplay.name(course.nameCn, course.nameEn)).font(.headline)
            }
            if let section = schedule.section {
                Text(section.code).font(.caption).foregroundStyle(.secondary)
                if let semester = section.semester {
                    Text(ServerCatalogDisplay.semesterName(semester, locale: locale))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(schedule.date.map { String($0.prefix(10)) } ?? String(localized: "Date unavailable"))
            Text("\(ServerCatalogDisplay.time(schedule.startTime)) – \(ServerCatalogDisplay.time(schedule.endTime))")
            if let week = schedule.weekIndex {
                Text(String(format: "Week %lld".localized, Int64(week))).font(.caption)
            }
            if let place = schedule.customPlace ?? schedule.room?.namePrimary ?? schedule.room?.name ?? schedule.room?.code {
                Label(place, systemImage: "mappin.and.ellipse").font(.caption)
            }
            if let building = schedule.room?.building {
                if let name = building.namePrimary ?? building.name ?? building.code {
                    Label(name, systemImage: "building.2").font(.caption)
                }
                if let campus = building.campus {
                    Text(ServerCatalogDisplay.name(campus.nameCn, campus.nameEn)).font(.caption)
                }
            }
        }
    }
}

private struct ServerPublicScheduleFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State var filters: ServerPublicScheduleFilters
    let apply: (ServerPublicScheduleFilters) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Section code") {
                        TextField("Section code", text: $filters.sectionCode)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("public_schedule_section_code")
                    }
                    LabeledContent("Teacher code") {
                        TextField("Teacher code", text: $filters.teacherCode)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("public_schedule_teacher_code")
                    }
                    LabeledContent("University room ID") {
                        TextField("University room ID", text: $filters.roomJWID)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("public_schedule_room_code")
                    }
                } footer: {
                    Text("Use exact section and teacher codes, or the university's numeric room ID.")
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Section {
                    Picker("Weekday", selection: $filters.weekday) {
                        Text("Any weekday").tag(nil as Int?)
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayName(day)).tag(Optional(day))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("public_schedule_weekday")
                    Toggle("Limit dates", isOn: $filters.limitsDates)
                        .accessibilityIdentifier("public_schedule_limit_dates")
                    if filters.limitsDates {
                        DatePicker("From", selection: $filters.dateFrom, displayedComponents: .date)
                            .accessibilityIdentifier("public_schedule_date_from")
                        DatePicker("To", selection: $filters.dateTo, displayedComponents: .date)
                            .accessibilityIdentifier("public_schedule_date_to")
                    }
                } footer: {
                    Text("Dates use Shanghai time.")
                }
                if let error = filters.validationError {
                    Text(error).foregroundStyle(.red)
                }
                Button("Reset Filters") { filters = ServerPublicScheduleFilters() }
                    .accessibilityIdentifier("public_schedule_reset")
            }
            .environment(\.calendar, YoungCalendarDate.calendar)
            .environment(\.timeZone, YoungCalendarDate.shanghai)
            .navigationTitle("Schedule Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("public_schedule_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply Filters") { apply(filters); dismiss() }
                        .disabled(filters.validationError != nil)
                        .accessibilityIdentifier("public_schedule_apply")
                }
            }
        }
    }

    private func weekdayName(_ day: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.weekdaySymbols[day % 7]
    }
}
