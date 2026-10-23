import SwiftUI

struct HomeView: View {
    @Bindable private var account = ServerAccountStore.shared

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
            }
            Section("Learning workspace") {
                NavigationLink {
                    ServerSubscriptionsView()
                } label: {
                    Label("Section subscriptions", systemImage: "books.vertical")
                }
                .accessibilityIdentifier("home_subscriptions")
                NavigationLink {
                    WorkspaceCalendarView()
                } label: {
                    Label("My Calendar", systemImage: "calendar")
                }
                .accessibilityIdentifier("home_calendar")
                NavigationLink {
                    TodoListView()
                } label: {
                    Label("Todos", systemImage: "checklist")
                }
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
    }
}
