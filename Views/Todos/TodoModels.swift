import SwiftUI

enum ServerTodoStatus: String, CaseIterable {
    case pending, completed, all

    var title: String {
        switch self {
        case .pending: "Pending"
        case .completed: "Completed"
        case .all: "All"
        }
    }

    var completed: Bool? {
        switch self {
        case .pending: false
        case .completed: true
        case .all: nil
        }
    }
}

struct ServerTodoListQuery: Equatable {
    var status: ServerTodoStatus = .pending
    var priority: TodoPriority?
    var dueFrom: Date?
    var dueThrough: Date?

    var filters: ServerTodoFilters {
        ServerTodoFilters(
            completed: status.completed,
            priority: priority,
            dueBefore: dueThrough.map {
                YoungCalendarDate.calendar.date(byAdding: .day, value: 1, to: YoungCalendarDate.dayStart($0))!
            },
            dueAfter: dueFrom.map(YoungCalendarDate.dayStart)
        )
    }

    var hasAdditionalFilters: Bool {
        priority != nil || dueFrom != nil || dueThrough != nil
    }

    var isValid: Bool {
        guard let dueFrom, let dueThrough else { return true }
        return YoungCalendarDate.dayStart(dueFrom) <= YoungCalendarDate.dayStart(dueThrough)
    }
}

@Observable
@MainActor
final class ServerTodoListModel {
    var query = ServerTodoListQuery()
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var mutationError: String?
    private(set) var mutatingIDs: Set<String> = []

    private let client: ServerClient
    private var snapshot: ServerTodoCollection?
    private var snapshotQuery: ServerTodoListQuery?
    private var loadedRevision: UUID?
    private var generation = 0
    private var failedMutation: Mutation?

    private enum Mutation {
        case completion(id: String, completed: Bool)
        case delete(id: String)

        var id: String {
            switch self {
            case .completion(let id, _), .delete(let id): id
            }
        }
    }

    init(client: ServerClient = .shared) {
        self.client = client
    }

    var todos: [ServerTodo] {
        ownsSnapshot ? snapshot?.todos ?? [] : []
    }

    var counts: ServerTodoCounts? {
        ownsSnapshot ? snapshot?.counts : nil
    }

    var showsPreviousFilterResults: Bool {
        ownsSnapshot && snapshot != nil && snapshotQuery != query
    }

    var canRetryMutation: Bool {
        ownsSnapshot && failedMutation != nil && mutatingIDs.isEmpty
    }

    private var ownsSnapshot: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        let requestedQuery = query
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
        guard requestedQuery.isValid else {
            loadError = String(localized: "The end date must be on or after the start date.")
            return
        }
        do {
            let result = try await client.fetchAllTodos(filters: requestedQuery.filters)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  requestedQuery == query, !Task.isCancelled else { return }
            snapshot = result
            snapshotQuery = requestedQuery
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  requestedQuery == query, !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    func toggleCompletion(_ todo: ServerTodo) async -> Bool {
        await mutate(.completion(id: todo.id, completed: !todo.completed))
    }

    @discardableResult
    func delete(_ todo: ServerTodo) async -> Bool {
        await mutate(.delete(id: todo.id))
    }

    @discardableResult
    func retryMutation() async -> Bool {
        guard canRetryMutation, let failedMutation else { return false }
        return await mutate(failedMutation)
    }

    private func mutate(_ mutation: Mutation) async -> Bool {
        guard ownsSnapshot,
              todos.contains(where: { $0.id == mutation.id }) || failedMutation?.id == mutation.id,
              !mutatingIDs.contains(mutation.id) else { return false }
        let revision = client.sessionRevision
        mutatingIDs.insert(mutation.id)
        mutationError = nil
        failedMutation = nil
        defer {
            if revision == client.sessionRevision {
                mutatingIDs.remove(mutation.id)
            } else {
                resetForSessionIfNeeded()
            }
        }
        do {
            switch mutation {
            case .completion(let id, let completed):
                _ = try await client.updateTodo(id: id, request: UpdateTodoRequest(completed: completed), expectedRevision: revision)
            case .delete(let id):
                try await client.deleteTodo(id: id, expectedRevision: revision)
            }
            return revision == client.sessionRevision && !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return false }
            mutationError = error.localizedDescription
            failedMutation = mutation
            return false
        }
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision || !client.isAuthenticated else { return }
        loadedRevision = client.sessionRevision
        snapshot = nil
        snapshotQuery = nil
        loadError = nil
        mutationError = nil
        failedMutation = nil
        mutatingIDs = []
    }
}

@Observable
@MainActor
final class ServerTodoEditorModel {
    var title: String
    var content: String
    var priority: TodoPriority
    var hasDueDate: Bool
    var dueDate: Date
    private(set) var isSaving = false
    private(set) var error: String?
    private(set) var hasSaved = false

    private let original: ServerTodo?
    private let client: ServerClient
    private let revision: UUID

    init(todo: ServerTodo? = nil, client: ServerClient = .shared) {
        original = todo
        self.client = client
        revision = client.sessionRevision
        title = todo?.title ?? ""
        content = todo?.content ?? ""
        priority = todo?.priority ?? .medium
        hasDueDate = todo?.dueAt != nil
        dueDate = todo?.dueAt ?? Date().addingTimeInterval(86400)
    }

    var isEditing: Bool { original != nil }

    var isCurrentSession: Bool {
        client.isAuthenticated && revision == client.sessionRevision
    }

    var validationError: String? {
        if normalizedTitle.isEmpty {
            return String(localized: "Enter a title.")
        }
        if normalizedTitle.utf16.count > 200 {
            return String(localized: "The title must be 200 characters or fewer.")
        }
        if (normalizedContent?.utf16.count ?? 0) > 4000 {
            return String(localized: "Notes must be 4,000 characters or fewer.")
        }
        return nil
    }

    var hasChanges: Bool {
        guard let original else { return true }
        return normalizedTitle != original.title
            || normalizedContent != Self.normalizeContent(original.content ?? "")
            || priority != original.priority || dueDateChanged
    }

    var canSave: Bool {
        isCurrentSession && !isSaving && !hasSaved && validationError == nil && hasChanges
    }

    @discardableResult
    func save() async -> Bool {
        guard !isSaving, !hasSaved else { return false }
        guard isCurrentSession else {
            error = String(localized: "Your session changed. Reopen this todo to continue.")
            return false
        }
        guard validationError == nil else {
            error = validationError
            return false
        }
        guard hasChanges else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            if let original {
                _ = try await client.updateTodo(id: original.id, request: updateRequest(), expectedRevision: revision)
            } else {
                _ = try await client.createTodo(CreateTodoRequest(
                    title: normalizedTitle, content: normalizedContent,
                    priority: priority.rawValue, dueAt: hasDueDate ? encodedDueDate : nil
                ), expectedRevision: revision)
            }
            guard isCurrentSession, !Task.isCancelled else { return false }
            hasSaved = true
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard isCurrentSession, !Task.isCancelled else { return false }
            self.error = error.localizedDescription
            return false
        }
    }

    private var normalizedTitle: String { Self.trim(title) }
    private var normalizedContent: String? { Self.normalizeContent(content) }

    private var dueDateChanged: Bool {
        hasDueDate != (original?.dueAt != nil) || (hasDueDate && dueDate != original?.dueAt)
    }

    private var encodedDueDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: dueDate)
    }

    private func updateRequest() -> UpdateTodoRequest {
        let previousContent = Self.normalizeContent(original?.content ?? "")
        let updatedContent: ServerPatchValue<String> = normalizedContent == previousContent
            ? .unchanged : normalizedContent.map(ServerPatchValue.value) ?? .null
        let updatedDueDate: ServerPatchValue<String> = !dueDateChanged
            ? .unchanged : hasDueDate ? .value(encodedDueDate) : .null
        return UpdateTodoRequest(
            title: normalizedTitle == original?.title ? nil : normalizedTitle,
            content: updatedContent,
            priority: priority == original?.priority ? nil : priority.rawValue,
            dueAt: updatedDueDate
        )
    }

    private static func trim(_ text: String) -> String {
        // Match ECMAScript trim, which the server applies before validating lengths.
        let whitespace = CharacterSet(charactersIn:
            "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{00A0}\u{1680}"
                + "\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}"
                + "\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
        return text.trimmingCharacters(in: whitespace)
    }

    private static func normalizeContent(_ text: String) -> String? {
        let trimmed = trim(text)
        return trimmed.isEmpty ? nil : trimmed
    }
}
