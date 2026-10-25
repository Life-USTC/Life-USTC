import SwiftUI
import LifeClientCore

struct YoungBrowseFilters: Hashable {
    var search = ""
    var category = ""
    var module: String?
    var activityLevel: String?
    var organizerId: String?
    var active: Bool?
    var basis: YoungEventTimeBasis = .activity
    var dateFrom: Date?
    var dateTo: Date?

    var categoryValue: String? { nonempty(category) }

    var query: YoungEventQuery {
        YoungEventQuery(
            search: search, category: category, module: module ?? "",
            activityLevel: activityLevel ?? "", organizerID: organizerId ?? "", active: active,
            dateFrom: dateFrom.map(YoungCalendarDate.dateString) ?? "",
            dateTo: dateTo.map(YoungCalendarDate.dateString) ?? "", timeBasis: basis.queryValue
        )
    }

    var hasSelections: Bool {
        categoryValue != nil || module != nil || activityLevel != nil
            || organizerId != nil || active != nil || basis != .activity || dateFrom != nil || dateTo != nil
    }

    private func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct YoungBrowseFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: YoungBrowseFilters
    @State private var organizers = YoungOrganizersViewModel()
    private let dateUnknown: Bool
    private let apply: (YoungBrowseFilters) -> Void

    init(filters: YoungBrowseFilters, dateUnknown: Bool, apply: @escaping (YoungBrowseFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.dateUnknown = dateUnknown
        self.apply = apply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category", text: $draft.category)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("young.filters.category")
                } footer: {
                    Text("Enter the exact category shown on an activity.")
                }
                Section {
                    Picker("Module", selection: $draft.module) {
                        Text("All").tag(nil as String?)
                        ForEach(["德", "智", "体", "美", "劳"], id: \.self) { value in
                            Text(value).tag(Optional(value))
                        }
                    }
                    .accessibilityIdentifier("young.filters.module")
                    Picker("Activity level", selection: $draft.activityLevel) {
                        Text("All").tag(nil as String?)
                        ForEach(["班级", "院级", "校级", "省级", "国家级"], id: \.self) { value in
                            Text(value).tag(Optional(value))
                        }
                    }
                    .accessibilityIdentifier("young.filters.activityLevel")
                    Picker("Time basis", selection: $draft.basis) {
                        ForEach(YoungEventTimeBasis.allCases) { basis in
                            Text(LocalizedStringKey(basis.title)).tag(basis)
                        }
                    }
                    .accessibilityIdentifier("young.filters.timeBasis")
                }
                Section {
                    if dateUnknown {
                        Text("Date ranges do not apply to activities with unknown dates.")
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle("Filter by date", isOn: Binding(
                            get: { draft.dateFrom != nil || draft.dateTo != nil },
                            set: { enabled in
                                let today = YoungCalendarDate.dayStart(Date())
                                draft.dateFrom = enabled ? today : nil
                                draft.dateTo = enabled ? today : nil
                            }
                        ))
                        .accessibilityIdentifier("young.filters.dateRange")
                        if draft.dateFrom != nil || draft.dateTo != nil {
                            DatePicker("From date", selection: Binding(
                                get: { draft.dateFrom ?? YoungCalendarDate.dayStart(Date()) },
                                set: { date in
                                    draft.dateFrom = date
                                    draft.dateTo = min(max(draft.dateTo ?? date, date), latestDate)
                                }
                            ), displayedComponents: .date)
                                .accessibilityIdentifier("young.filters.dateFrom")
                            DatePicker("Through date", selection: Binding(
                                get: { draft.dateTo ?? YoungCalendarDate.dayStart(Date()) },
                                set: { draft.dateTo = $0 }
                            ), in: lowerDate...latestDate, displayedComponents: .date)
                                .accessibilityIdentifier("young.filters.dateTo")
                        }
                    }
                } header: {
                    Text("Date range")
                } footer: {
                    if !dateUnknown { Text("Choose up to 366 days. Dates use Shanghai time and the selected time basis.") }
                }
                Section {
                    Picker("Source signup list", selection: $draft.active) {
                        Text("All").tag(nil as Bool?)
                        Text("In source signup list").tag(Optional(true))
                        Text("Not in source signup list").tag(Optional(false))
                    }
                    .accessibilityIdentifier("young.filters.active")
                } footer: {
                    Text("Source list membership does not indicate whether registration is open.")
                }
                Section {
                    Picker("Organizer", selection: $draft.organizerId) {
                        Text("All").tag(nil as String?)
                        if let selected = draft.organizerId,
                           !organizers.organizers.contains(where: { $0.id == selected }) {
                            Text("Selected organizer").tag(Optional(selected))
                        }
                        ForEach(organizers.organizers) { organizer in
                            Text(organizer.name).tag(Optional(organizer.id))
                        }
                    }
                    .accessibilityIdentifier("young.filters.organizer")
                    if let error = organizers.error {
                        Text(error).foregroundStyle(.red)
                        Button("Retry") { Task { await organizers.load() } }
                            .disabled(organizers.isLoading)
                            .accessibilityIdentifier("young.filters.organizers.retry")
                    }
                    if organizers.isLoading { ProgressView() }
                }
                Button("Clear filters") { draft = .init(search: draft.search) }
                    .accessibilityIdentifier("young.filters.clear")
            }
            .pickerStyle(.menu)
            .navigationTitle("Activity filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("young.filters.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply(draft); dismiss() }
                        .accessibilityIdentifier("young.filters.apply")
                }
            }
        }
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task { await organizers.load() }
    }

    private var lowerDate: Date { draft.dateFrom ?? .distantPast }
    private var latestDate: Date {
        YoungCalendarDate.calendar.date(byAdding: .day, value: 365, to: lowerDate) ?? .distantFuture
    }
}
