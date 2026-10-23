import SwiftUI

@Observable
@MainActor
final class ServerWorkspaceCalendarModel {
    var mode: YoungCalendarDisplayMode = .week
    var referenceDate = Date()
    private var snapshot: [ServerPersonalCalendarEvent] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let client: ServerClient
    private var generation = 0
    private var loadedRequest: String?

    init(client: ServerClient = .shared) { self.client = client }

    var requestID: String {
        "\(mode.rawValue)-\(YoungCalendarDate.dateString(referenceDate))"
    }

    private var snapshotKey: String { "\(client.sessionRevision)-\(requestID)" }

    var events: [ServerPersonalCalendarEvent] {
        client.isAuthenticated && loadedRequest == snapshotKey ? snapshot : []
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        let key = snapshotKey
        if key != loadedRequest {
            snapshot = []
            loadedRequest = key
        }
        error = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else {
            snapshot = []
            return
        }
        let range = YoungCalendarDate.range(for: mode, date: referenceDate)
        defer {
            if requestGeneration == generation {
                isLoading = false
                if revision != client.sessionRevision {
                    snapshot = []
                    loadedRequest = nil
                }
            }
        }
        do {
            let result = try await client.fetchPersonalCalendarEvents(dateFrom: range.from, dateTo: range.to)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  key == snapshotKey, !Task.isCancelled else { return }
            snapshot = result
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  key == snapshotKey, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
