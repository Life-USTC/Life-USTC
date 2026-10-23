import SwiftUI

struct HomeView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = WorkspaceHomeModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            if let error = account.learningSyncError {
                Section("Cached timetable") {
                    Text("The cached timetable could not be refreshed.")
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await account.refreshLearningData() } }
                }
            }
            if !account.isAuthenticated {
                Section {
                    YoungLoginRequiredView()
                        .listRowBackground(Color.clear)
                }
            } else {
                if let error = model.error {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await model.load() } }
                            .accessibilityIdentifier("home_retry")
                    }
                }
                if let overview = model.overview {
                    if let focus = overview.focus {
                        Section(LocalizedStringKey(focus.status.title)) {
                            WorkspaceEventLink(event: focus.event)
                        }
                    }
                    if !overview.urgency.isEmpty {
                        Section("Needs attention") {
                            ForEach(overview.urgency) { WorkspaceEventLink(event: $0) }
                        }
                    }
                    if !overview.upcoming.isEmpty {
                        Section("Coming up") {
                            ForEach(overview.upcoming) { WorkspaceEventLink(event: $0) }
                        }
                    }
                    Section("Deadlines") {
                        ForEach(WorkspaceDeadlineGroup.allCases) { group in
                            NavigationLink {
                                WorkspaceDeadlineListView(group: group)
                            } label: {
                                LabeledContent(LocalizedStringKey(group.title), value: String(group.events(in: overview).count))
                            }
                            .accessibilityIdentifier("home_deadlines_\(group.rawValue)")
                        }
                    }
                } else if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            Section("Learning workspace") {
                NavigationLink {
                    ServerSubscriptionsView()
                } label: {
                    Label("Section subscriptions", systemImage: "books.vertical")
                    if let overview = model.overview {
                        Spacer()
                        Text(overview.subscriptions.totalCount, format: .number)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("home_subscriptions")
                NavigationLink {
                    WorkspaceCalendarView()
                } label: {
                    Label("My Calendar", systemImage: "calendar")
                }
                .accessibilityIdentifier("home_calendar")
                NavigationLink {
                    ServerHomeworkListView()
                } label: {
                    Label("Shared homework", systemImage: "doc.text")
                }
                .accessibilityIdentifier("home_homeworks")
                NavigationLink {
                    TodoListView()
                } label: {
                    Label("Todos", systemImage: "checklist")
                }
                .accessibilityIdentifier("home_todos")
                NavigationLink {
                    ServerWorkspaceExamsView()
                } label: {
                    Label("Subscribed exams", systemImage: "pencil.and.list.clipboard")
                }
                .accessibilityIdentifier("home_exams")
            }
            Section("Explore") {
                NavigationLink {
                    ServerCatalogView()
                } label: {
                    Label("Course catalog", systemImage: "magnifyingglass")
                }
                .accessibilityIdentifier("home_catalog")
                NavigationLink {
                    YoungCommunityView()
                } label: {
                    Label("Second Classroom", systemImage: "figure.run")
                }
            }
        }
        .navigationTitle("Life@USTC")
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable {
            await model.load()
            await account.refreshLearningData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await model.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.load() }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            if scenePhase == .active, account.isAuthenticated, !model.isLoading {
                Task { await model.load() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
    }
}
