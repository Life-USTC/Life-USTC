import SwiftUI

enum ServerHomeworkStatus: String, CaseIterable {
    case pending, completed, all

    var title: String {
        switch self {
        case .pending: "Pending"
        case .completed: "Completed"
        case .all: "All"
        }
    }
}

@Observable
@MainActor
final class ServerHomeworkListModel {
    var status: ServerHomeworkStatus = .pending
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var mutationError: String?
    private(set) var mutatingID: String?

    private let client: ServerClient
    private var snapshot: [ServerHomework] = []
    private var loadedRevision: UUID?
    private var generation = 0
    private var failedCompletion: (id: String, completed: Bool)?

    init(client: ServerClient = .shared) { self.client = client }

    var homeworks: [ServerHomework] { ownsSnapshot ? snapshot : [] }
    var canRetryMutation: Bool { ownsSnapshot && failedCompletion != nil && mutatingID == nil }

    private var ownsSnapshot: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision
    }

    func visibleHomeworks(at date: Date) -> [ServerHomework] {
        homeworks.filter { homework in
            switch status {
            case .pending: homework.isPending(at: date)
            case .completed: !homework.isPending(at: date)
            case .all: true
            }
        }
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        resetForSessionIfNeeded()
        loadError = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else { return }
        defer {
            if requestGeneration == generation {
                isLoading = false
                resetForSessionIfNeeded()
            }
        }
        do {
            let loaded = try await client.fetchAllSubscribedHomeworks()
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = loaded
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    func toggleCompletion(_ homework: ServerHomework) async -> Bool {
        await setCompletion(id: homework.id, completed: homework.completion == nil)
    }

    @discardableResult
    func retryMutation() async -> Bool {
        guard canRetryMutation, let failedCompletion else { return false }
        return await setCompletion(id: failedCompletion.id, completed: failedCompletion.completed)
    }

    private func setCompletion(id: String, completed: Bool) async -> Bool {
        guard ownsSnapshot, mutatingID == nil,
              homeworks.contains(where: { $0.id == id && $0.completionRequired }) else { return false }
        let revision = client.sessionRevision
        mutatingID = id
        mutationError = nil
        failedCompletion = nil
        defer {
            if revision == client.sessionRevision { mutatingID = nil }
            else { resetForSessionIfNeeded() }
        }
        do {
            _ = try await client.setHomeworkCompletion(id: id, completed: completed, expectedRevision: revision)
            return revision == client.sessionRevision && !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return false }
            mutationError = error.localizedDescription
            failedCompletion = (id, completed)
            return false
        }
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision || !client.isAuthenticated else { return }
        loadedRevision = client.sessionRevision
        snapshot = []
        loadError = nil
        mutationError = nil
        failedCompletion = nil
        mutatingID = nil
    }
}

@Observable
@MainActor
final class ServerHomeworkDetailModel {
    let homeworkID: String
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadError: String?
    private(set) var mutationError: String?

    private let client: ServerClient
    private var snapshot: ServerHomework?
    private var loadedRevision: UUID?
    private var generation = 0
    private var failedCompletion: Bool?

    init(homeworkID: String, client: ServerClient = .shared) {
        self.homeworkID = homeworkID
        self.client = client
    }

    var homework: ServerHomework? { ownsSnapshot ? snapshot : nil }
    var canRetryMutation: Bool { ownsSnapshot && failedCompletion != nil && !isSaving }
    private var ownsSnapshot: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        resetForSessionIfNeeded()
        loadError = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else { return }
        defer {
            if requestGeneration == generation {
                isLoading = false
                resetForSessionIfNeeded()
            }
        }
        do {
            let loaded = try await client.fetchHomework(id: homeworkID)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = loaded
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    func toggleCompletion() async -> Bool {
        guard let homework else { return false }
        return await setCompletion(homework.completion == nil)
    }

    @discardableResult
    func retryMutation() async -> Bool {
        guard canRetryMutation, let failedCompletion else { return false }
        return await setCompletion(failedCompletion)
    }

    private func setCompletion(_ completed: Bool) async -> Bool {
        guard let homework, homework.completionRequired, !isSaving else { return false }
        let revision = client.sessionRevision
        isSaving = true
        mutationError = nil
        failedCompletion = nil
        defer {
            if revision == client.sessionRevision { isSaving = false }
            else { resetForSessionIfNeeded() }
        }
        do {
            _ = try await client.setHomeworkCompletion(id: homeworkID, completed: completed, expectedRevision: revision)
            return revision == client.sessionRevision && !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return false }
            mutationError = error.localizedDescription
            failedCompletion = completed
            return false
        }
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision || !client.isAuthenticated else { return }
        loadedRevision = client.sessionRevision
        snapshot = nil
        loadError = nil
        mutationError = nil
        failedCompletion = nil
        isSaving = false
    }
}
