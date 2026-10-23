import SwiftUI

struct ServerHomeworkDetailView: View {
    @State private var model: ServerHomeworkDetailModel
    @Bindable private var account = ServerAccountStore.shared

    init(homeworkID: String) {
        _model = State(initialValue: ServerHomeworkDetailModel(homeworkID: homeworkID))
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            List {
                if !account.isAuthenticated {
                    ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle",
                                           description: Text("Sign in to view your subscribed homework."))
                    NavigationLink("Sign In") { ServerAccountView() }
                } else {
                    if let error = model.loadError {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.load() } }
                                .accessibilityIdentifier("homework.detail.load.retry")
                        }
                    }
                    if let homework = model.homework {
                        Section {
                            Text(homework.title).font(.title2.bold())
                            ServerHomeworkStateView(homework: homework, referenceDate: context.date)
                            if homework.isMajor { Label("Major assignment", systemImage: "star") }
                            if homework.requiresTeam { Label("Group work", systemImage: "person.2") }
                            if let section = homework.section {
                                NavigationLink {
                                    ServerSectionDetailView(jwId: section.jwId)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ServerCatalogDisplay.name(section.course.nameCn, section.course.nameEn))
                                        Text(section.code).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityIdentifier("homework.detail.section")
                            }
                        }

                        Section("Details") {
                            if let content = homework.description?.content, !content.isEmpty {
                                Text((try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                                     ?? AttributedString(content))
                                    .textSelection(.enabled)
                            } else {
                                Text("No description.").foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            if let date = homework.publishedAt { dateRow("Published", date: date) }
                            if let date = homework.submissionStartAt { dateRow("Submission opens", date: date) }
                            if let date = homework.submissionDueAt { dateRow("Deadline", date: date) }
                            else { LabeledContent("Deadline", value: String(localized: "Date unavailable")) }
                            if let completion = homework.completion { dateRow("Completed", date: completion.completedAt) }
                        }

                        Section {
                            if homework.completionRequired {
                                Button(LocalizedStringKey(homework.completion == nil ? "Mark as Completed" : "Mark as Pending")) {
                                    Task { await model.toggleCompletion() }
                                }
                                .disabled(model.isSaving)
                                .accessibilityIdentifier("homework.detail.complete")
                                if model.isSaving { ProgressView() }
                            } else {
                                Text("No completion is required for your teaching-assistant subscription.")
                                    .foregroundStyle(.secondary)
                            }
                            if let error = model.mutationError {
                                Text(error).foregroundStyle(.red)
                                Button("Retry") { Task { await model.retryMutation() } }
                                    .disabled(!model.canRetryMutation)
                                    .accessibilityIdentifier("homework.detail.mutation.retry")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Homework")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("homework.detail")
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
            if model.isLoading && model.homework == nil { ProgressView() }
        }
    }

    private func dateRow(_ title: LocalizedStringKey, date: Date) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                Text(date, style: .date)
                Text(date, style: .time)
            }
        }
    }
}
