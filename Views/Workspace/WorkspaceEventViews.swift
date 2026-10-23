import SwiftUI

extension ServerOverviewFocusStatus {
    var title: String {
        switch self {
        case .now: "Happening now"
        case .urgent: "Needs attention"
        case .next: "Up next"
        }
    }
}

struct WorkspaceEventLink: View {
    let event: ServerPersonalCalendarEvent

    var body: some View {
        NavigationLink {
            WorkspaceEventDestination(event: event)
        } label: {
            WorkspaceEventLabel(event: event)
        }
        .accessibilityIdentifier("workspace_event_\(event.id)")
    }
}

private struct WorkspaceEventDestination: View {
    let event: ServerPersonalCalendarEvent

    @ViewBuilder
    var body: some View {
        if let target = event.target {
            switch target.kind {
            case .section:
                if let jwID = Int(target.id) {
                    ServerSectionDetailView(jwId: jwID)
                } else {
                    information
                }
            case .exam:
                if let examID = Int(target.id) {
                    ServerWorkspaceExamDetailView(examID: examID)
                } else {
                    information
                }
            case .homework:
                ServerHomeworkDetailView(homeworkID: target.id)
            case .todo:
                ServerTodoDetailView(todoID: target.id)
            case .youngEvent:
                YoungEventDetailView(youngId: target.id)
            }
        } else if let youngID = event.youngId {
            YoungEventDetailView(youngId: youngID)
        } else {
            information
        }
    }

    private var information: some View {
        List {
            WorkspaceEventLabel(event: event)
            if let content = event.content, !content.isEmpty {
                Text(.init(content)).textSelection(.enabled)
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkspaceEventLabel: View {
    let event: ServerPersonalCalendarEvent

    private var typeTitle: String {
        switch event.type {
        case "schedule": "Course"
        case "exam": "Exam"
        case "homework_due": "Shared homework"
        case "todo_due": "Todo"
        case "young_event": "Activity"
        default: "Calendar"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.title).font(.headline)
                Spacer()
                Text(LocalizedStringKey(typeTitle)).font(.caption2).foregroundStyle(.secondary)
            }
            if let at = event.at {
                if event.hasTime == false {
                    Text(YoungCalendarDate.dateString(at)).font(.subheadline)
                    Text("Time unavailable").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(YoungFormatting.dateRange(at, event.endsAt, includeYear: true))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Text("Date unavailable").font(.subheadline).foregroundStyle(.secondary)
            }
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse").font(.caption)
            }
            if let section = event.sectionCode {
                Text(section).font(.caption).foregroundStyle(.secondary)
            }
            if let teachers = event.teachers, !teachers.isEmpty {
                Text(teachers.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
            }
            if let role = event.subscriptionKind, role != .regular {
                Text(role.title).font(.caption).foregroundStyle(.secondary)
            }
            if let priority = event.priority {
                Label(LocalizedStringKey(priority.displayName), systemImage: priority.iconName)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

enum WorkspaceDeadlineGroup: String, CaseIterable, Identifiable {
    case today, nextThreeDays, allPending
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Due today"
        case .nextThreeDays: "Due in the next three days"
        case .allPending: "All pending deadlines"
        }
    }

    func events(in overview: ServerActionableOverview) -> [ServerPersonalCalendarEvent] {
        switch self {
        case .today: overview.deadlines.today
        case .nextThreeDays: overview.deadlines.nextThreeDays
        case .allPending: overview.deadlines.allPending
        }
    }
}

struct WorkspaceDeadlineListView: View {
    let group: WorkspaceDeadlineGroup
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = WorkspaceHomeModel()

    var body: some View {
        List {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                if let error = model.error {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.load() } }
                }
                if let overview = model.overview {
                    let events = group.events(in: overview)
                    if events.isEmpty {
                        ContentUnavailableView("No pending deadlines", systemImage: "checkmark.circle")
                    }
                    ForEach(events) { WorkspaceEventLink(event: $0) }
                }
                if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .navigationTitle(LocalizedStringKey(group.title))
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await model.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.load() }
        }
    }
}
