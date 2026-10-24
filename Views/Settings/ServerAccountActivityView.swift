import SwiftUI

@Observable
@MainActor
final class ServerAccountActivityModel {
    private let client: ServerClient
    private var revision: UUID?
    private var snapshot: [ServerAccountActivity] = []
    private var cursor: String?
    private var generation = 0
    private var lastRequestWasRefresh = true
    private(set) var isLoading = false
    private(set) var error: String?

    init(client: ServerClient = .shared) { self.client = client }

    private var ownsSnapshot: Bool { client.isAuthenticated && revision == client.sessionRevision }
    var items: [ServerAccountActivity] { ownsSnapshot ? snapshot : [] }
    var hasMore: Bool { ownsSnapshot && cursor != nil }

    func retry() async { await load(refresh: lastRequestWasRefresh) }

    func load(refresh: Bool = true) async {
        if !refresh && (!hasMore || isLoading) { return }
        let revision = client.sessionRevision
        if self.revision != revision {
            self.revision = revision
            snapshot = []
            cursor = nil
        }
        generation += 1
        let current = generation
        error = nil
        guard client.isAuthenticated else { isLoading = false; return }
        isLoading = true
        lastRequestWasRefresh = refresh
        defer { if current == generation { isLoading = false } }
        do {
            let page = try await client.fetchAccountActivity(cursor: refresh ? nil : cursor, expectedRevision: revision)
            guard current == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            snapshot = refresh ? page.items : snapshot + page.items
            cursor = page.nextCursor
        } catch is CancellationError {
            return
        } catch {
            guard current == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

struct ServerAccountActivityView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = ServerAccountActivityModel()

    var body: some View {
        List {
            Section {
                if !account.isAuthenticated {
                    NavigationLink("Sign In") { ServerAccountView() }
                } else {
                    if model.items.isEmpty && !model.isLoading && model.error == nil {
                        Text("No app activity yet.").foregroundStyle(.secondary)
                    }
                    ForEach(model.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.headline)
                            HStack {
                                Text(item.createdAt, style: .date)
                                Text(item.createdAt, style: .time)
                                Spacer()
                                Text(outcomeTitle(item.outcome))
                                    .foregroundStyle(item.outcome == .success ? Color.secondary : Color.red)
                            }
                            .font(.caption)
                        }
                        .accessibilityIdentifier("account_activity_\(item.id)")
                    }
                    if model.hasMore {
                        Button("Load More") { Task { await model.load(refresh: false) } }
                            .disabled(model.isLoading)
                            .accessibilityIdentifier("account_activity_load_more")
                    }
                    if model.isLoading { ProgressView() }
                }
            } footer: {
                Text("Activity performed by this app with your current authorization. Manage all authorized apps on the website.")
            }
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.retry() } }
                    YoungReauthorizeButton()
                }
            }
        }
        .navigationTitle("This App's Activity")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
    }

    private func outcomeTitle(_ outcome: ServerAccountActivity.Outcome) -> LocalizedStringKey {
        switch outcome {
        case .success: "Succeeded"
        case .denied: "Denied"
        case .failure: "Failed"
        }
    }
}
