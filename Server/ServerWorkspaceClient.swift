import Foundation

extension Notification.Name {
    static let serverWorkspaceDidChange = Notification.Name("serverWorkspaceDidChange")
}

extension ServerClient {
    private func notifyWorkspaceChanged(revision: UUID) async throws {
        try await MainActor.run {
            try checkWorkspaceRead(revision: revision)
            NotificationCenter.default.post(name: .serverWorkspaceDidChange, object: nil)
        }
    }

    private func checkWorkspaceRead(revision: UUID) throws {
        try Task.checkCancellation()
        guard revision == sessionRevision else { throw CancellationError() }
    }

    private func collectWorkspacePages<Value: Codable>(
        pageSize: Int,
        load: (Int, Int) async throws -> PaginatedResponse<Value>
    ) async throws -> [Value] {
        let revision = sessionRevision
        var page = 1
        var values: [Value] = []
        while true {
            try checkWorkspaceRead(revision: revision)
            let response = try await load(page, pageSize)
            try checkWorkspaceRead(revision: revision)
            guard response.pagination.page == page else {
                throw ServerError.serverError("Invalid pagination response")
            }
            values.append(contentsOf: response.data)
            guard page < response.pagination.totalPages else { return values }
            page += 1
        }
    }

    func fetchTodosPage(
        page: Int = 1, pageSize: Int = 100, filters: ServerTodoFilters = .init()
    ) async throws -> ServerTodoPageResponse {
        try await request(.listTodosPage(page: page, pageSize: pageSize, filters: filters))
    }

    func fetchAllTodos(filters: ServerTodoFilters = .init()) async throws -> ServerTodoCollection {
        let revision = sessionRevision
        try checkWorkspaceRead(revision: revision)
        let first = try await fetchTodosPage(filters: filters)
        try checkWorkspaceRead(revision: revision)
        guard first.pagination.page == 1 else { throw ServerError.serverError("Invalid pagination response") }
        var todos = first.data
        var page = 1
        var totalPages = first.pagination.totalPages
        while page < totalPages {
            page += 1
            try checkWorkspaceRead(revision: revision)
            let response = try await fetchTodosPage(page: page, filters: filters)
            try checkWorkspaceRead(revision: revision)
            guard response.pagination.page == page else { throw ServerError.serverError("Invalid pagination response") }
            todos.append(contentsOf: response.data)
            totalPages = response.pagination.totalPages
        }
        return ServerTodoCollection(counts: first.meta.counts, todos: todos)
    }

    func createTodo(_ input: CreateTodoRequest, expectedRevision: UUID? = nil) async throws -> String {
        let revision = expectedRevision ?? sessionRevision
        try checkWorkspaceRead(revision: revision)
        let response: IDResponse = try await request(.createTodo(input), expectedRevision: revision)
        try await notifyWorkspaceChanged(revision: revision)
        return response.id
    }

    func updateTodo(id: String, request input: UpdateTodoRequest, expectedRevision: UUID? = nil) async throws -> ServerTodo {
        let revision = expectedRevision ?? sessionRevision
        try checkWorkspaceRead(revision: revision)
        let response: ServerTodoUpdateResponse = try await request(.updateTodo(id: id, input), expectedRevision: revision)
        try await notifyWorkspaceChanged(revision: revision)
        return response.todo
    }

    func deleteTodo(id: String, expectedRevision: UUID? = nil) async throws {
        let revision = expectedRevision ?? sessionRevision
        try checkWorkspaceRead(revision: revision)
        let _: SuccessResponse = try await request(.deleteTodo(id: id), expectedRevision: revision)
        try await notifyWorkspaceChanged(revision: revision)
    }

    func fetchSubscribedHomeworksPage(
        page: Int = 1, pageSize: Int = 50
    ) async throws -> PaginatedResponse<ServerHomework> {
        guard (1...50).contains(pageSize) else {
            throw ServerError.badRequest("Homework pageSize must be between 1 and 50")
        }
        return try await request(.listSubscribedHomeworks(page: page, pageSize: pageSize))
    }

    func fetchAllSubscribedHomeworks() async throws -> [ServerHomework] {
        try await collectWorkspacePages(pageSize: 50) { page, pageSize in
            try await fetchSubscribedHomeworksPage(page: page, pageSize: pageSize)
        }
    }

    func setHomeworkCompletion(id: String, completed: Bool, expectedRevision: UUID? = nil) async throws -> HomeworkCompletionResponse {
        let revision = expectedRevision ?? sessionRevision
        try checkWorkspaceRead(revision: revision)
        let response: HomeworkCompletionResponse = try await request(
            .setHomeworkCompletion(id: id, HomeworkCompletionRequest(completed: completed)), expectedRevision: revision
        )
        try await notifyWorkspaceChanged(revision: revision)
        return response
    }

    func fetchSubscribedExamsPage(
        page: Int = 1, pageSize: Int = 100, filters: ServerExamFilters = .init()
    ) async throws -> PaginatedResponse<ServerWorkspaceExam> {
        try await request(.listSubscribedExams(page: page, pageSize: pageSize, filters: filters))
    }

    func fetchAllSubscribedExams(filters: ServerExamFilters = .init()) async throws -> [ServerWorkspaceExam] {
        try await collectWorkspacePages(pageSize: 100) { page, pageSize in
            try await fetchSubscribedExamsPage(page: page, pageSize: pageSize, filters: filters)
        }
    }

    func fetchActionableOverview(atTime: Date? = nil, locale: String? = nil) async throws -> ServerActionableOverview {
        try await request(.actionableOverview(atTime: atTime.map { ISO8601DateFormatter().string(from: $0) }, locale: locale))
    }

    func fetchPersonalCalendarFeedURL() async throws -> URL? {
        let response: CalendarSubscriptionResponse = try await request(.getSubscriptions)
        guard let rawURL = response.subscription?.calendarUrl else { return nil }
        guard let url = URL(string: rawURL),
              let scheme = url.scheme, ["https", "http"].contains(scheme),
              url.host != nil else {
            throw ServerError.serverError("Invalid calendar feed URL")
        }
        return url
    }
}
