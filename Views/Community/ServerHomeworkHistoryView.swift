import SwiftUI

@Observable
@MainActor
final class ServerHomeworkHistoryModel {
    let sectionJwId: Int
    let homeworkID: String?
    private let client: ServerClient
    private var loadedRevision: UUID?
    private var snapshot: [ServerHomeworkAuditLog] = []
    private var generation = 0
    private var loading = false
    private var loadingError: String?

    init(sectionJwId: Int, homeworkID: String? = nil, client: ServerClient = .shared) {
        self.sectionJwId = sectionJwId
        self.homeworkID = homeworkID
        self.client = client
    }

    private var ownsSnapshot: Bool { loadedRevision == client.sessionRevision }
    var history: [ServerHomeworkAuditLog] { ownsSnapshot ? snapshot : [] }
    var isLoading: Bool { ownsSnapshot && loading }
    var error: String? { ownsSnapshot ? loadingError : nil }

    func load() async {
        let revision = client.sessionRevision
        if loadedRevision != revision {
            loadedRevision = revision
            snapshot = []
        }
        generation += 1
        let requestGeneration = generation
        loading = true
        loadingError = nil
        defer { if requestGeneration == generation { loading = false } }
        do {
            let entries: [ServerHomeworkAuditLog]
            if let homeworkID {
                let response = try await client.fetchHomeworkDetail(id: homeworkID)
                guard let auditLogs = response.auditLogs else {
                    throw ServerError.serverError(String(localized: "Homework history is unavailable."))
                }
                entries = auditLogs
            } else {
                entries = try await client.fetchHomeworkAudit(sectionJwId: sectionJwId)
            }
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = entries
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            loadingError = error.localizedDescription
        }
    }
}

struct ServerHomeworkHistoryView: View {
    @State private var model: ServerHomeworkHistoryModel
    @Bindable private var account = ServerAccountStore.shared

    init(sectionJwId: Int, homeworkID: String? = nil) {
        _model = State(initialValue: ServerHomeworkHistoryModel(sectionJwId: sectionJwId, homeworkID: homeworkID))
    }

    var body: some View {
        List {
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.load() } }
                        .accessibilityIdentifier("homework.history.retry")
                }
            }
            Section {
                if model.history.isEmpty && !model.isLoading && model.error == nil {
                    Text("No edit history.").foregroundStyle(.secondary)
                }
                ForEach(model.history) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(actionTitle(entry.action)).font(.headline)
                            Spacer()
                            Text(entry.createdAt, style: .date)
                            Text(entry.createdAt, style: .time)
                        }
                        .font(.caption)
                        if model.homeworkID == nil, entry.action != .deleted, let homeworkID = entry.homeworkId {
                            NavigationLink(entry.titleSnapshot ?? String(localized: "Homework")) {
                                ServerHomeworkDetailView(homeworkID: homeworkID)
                            }
                        } else if let title = entry.titleSnapshot {
                            Text(title)
                        }
                        if let actor = entry.actor { ServerCommunityActorLink(actor: actor) }
                        else { Text("Unknown author").foregroundStyle(.secondary) }
                    }
                    .accessibilityIdentifier("homework.history.\(entry.id)")
                }
            } footer: {
                Text("History includes up to 50 recent changes.")
            }
        }
        .navigationTitle("Homework History")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("homework.history")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverCommunityDidChange)) { _ in
            Task { await model.load() }
        }
        .overlay { if model.isLoading && model.history.isEmpty { ProgressView() } }
    }

    private func actionTitle(_ action: ServerHomeworkAuditAction) -> LocalizedStringKey {
        switch action {
        case .created: "Created"
        case .updated: "Updated"
        case .deleted: "Deleted"
        }
    }
}
