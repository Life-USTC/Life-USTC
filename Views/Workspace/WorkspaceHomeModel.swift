import SwiftUI

@Observable
@MainActor
final class WorkspaceHomeModel {
    private var snapshot: ServerActionableOverview?
    private(set) var isLoading = false
    private(set) var error: String?

    private let client: ServerClient
    private var loadedRevision: UUID?
    private var generation = 0

    init(client: ServerClient = .shared) {
        self.client = client
    }

    var overview: ServerActionableOverview? {
        client.isAuthenticated && loadedRevision == client.sessionRevision ? snapshot : nil
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        if loadedRevision != revision {
            snapshot = nil
            loadedRevision = revision
        }
        error = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else {
            snapshot = nil
            return
        }
        defer {
            if requestGeneration == generation {
                isLoading = false
                if loadedRevision != client.sessionRevision {
                    snapshot = nil
                    loadedRevision = client.sessionRevision
                }
            }
        }
        do {
            let locale = Locale.current.language.languageCode?.identifier == "en" ? "en-us" : "zh-cn"
            let result = try await client.fetchActionableOverview(locale: locale)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = result
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
