import SwiftUI

struct ServerHomeworkListView: View {
    @State private var model = ServerHomeworkListModel()
    @Bindable private var account = ServerAccountStore.shared

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            List {
                if !account.isAuthenticated {
                    ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle",
                                           description: Text("Sign in to view your subscribed homework."))
                    NavigationLink("Sign In") { ServerAccountView() }
                } else {
                    Picker("Homework Status", selection: $model.status) {
                        ForEach(ServerHomeworkStatus.allCases, id: \.self) { status in
                            Text(LocalizedStringKey(status.title)).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("homework.status")

                    if let error = model.loadError {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.load() } }
                                .accessibilityIdentifier("homework.load.retry")
                        }
                    }
                    if let error = model.mutationError {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.retryMutation() } }
                                .disabled(!model.canRetryMutation)
                                .accessibilityIdentifier("homework.mutation.retry")
                        }
                    }
                    let homeworks = model.visibleHomeworks(at: context.date)
                    if homeworks.isEmpty && !model.isLoading && model.loadError == nil {
                        ContentUnavailableView("No Homework", systemImage: "doc.text",
                                               description: Text("No shared homework matches this status."))
                    }
                    ForEach(homeworks) { homework in
                        HStack(spacing: 12) {
                            if homework.completionRequired {
                                Button {
                                    Task { await model.toggleCompletion(homework) }
                                } label: {
                                    if model.mutatingID == homework.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: homework.completion == nil ? "circle" : "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(homework.completion == nil ? Color.secondary : .green)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(model.mutatingID != nil)
                                .accessibilityLabel(Text(LocalizedStringKey(homework.completion == nil ? "Mark as Completed" : "Mark as Pending")))
                                .accessibilityIdentifier("homework.complete.\(homework.id)")
                            }
                            NavigationLink {
                                ServerHomeworkDetailView(homeworkID: homework.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(homework.title).font(.headline)
                                    if let section = homework.section {
                                        Text("\(ServerCatalogDisplay.name(section.course.nameCn, section.course.nameEn)) · \(section.code)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if homework.isMajor || homework.requiresTeam {
                                        HStack(spacing: 8) {
                                            if homework.isMajor { Label("Major assignment", systemImage: "star") }
                                            if homework.requiresTeam { Label("Group work", systemImage: "person.2") }
                                        }
                                        .font(.caption).foregroundStyle(.secondary)
                                    }
                                    ServerHomeworkStateView(homework: homework, referenceDate: context.date)
                                    if let dueAt = homework.submissionDueAt {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                            Text(dueAt, style: .date)
                                            Text(dueAt, style: .time)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(homework.isPending(at: context.date) && homework.completionRequired && dueAt < context.date
                                                         ? Color.red : .secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("homework.row.\(homework.id)")
                        }
                    }
                }
            }
        }
        .navigationTitle("Shared Homework")
        .accessibilityIdentifier("homework.list")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .environment(\.calendar, YoungCalendarDate.calendar)
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await model.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.load() }
        }
        .overlay {
            if model.isLoading && model.homeworks.isEmpty { ProgressView() }
        }
    }
}

struct ServerHomeworkStateView: View {
    let homework: ServerHomework
    let referenceDate: Date

    var body: some View {
        HStack(spacing: 8) {
            if homework.completion != nil {
                Label("Completed", systemImage: "checkmark.circle.fill")
            } else if !homework.completionRequired {
                Label("No completion required", systemImage: "clock")
                if !homework.isPending(at: referenceDate) { Text("Deadline passed") }
            } else if let dueAt = homework.submissionDueAt, dueAt < referenceDate {
                Text("Overdue").foregroundStyle(.red)
            } else {
                Text("Pending")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
