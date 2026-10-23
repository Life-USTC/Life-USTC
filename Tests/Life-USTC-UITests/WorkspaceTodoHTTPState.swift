import Foundation

/// Access is serialized by ServerJourneyHTTPFixture's network queue.
final class WorkspaceTodoHTTPState {
    static let initialTodoID = "00000000-0000-4000-8000-000000000001"
    static let completedTodoID = "00000000-0000-4000-8000-000000000002"

    private(set) var todos: [[String: Any]] = [
        ["id": WorkspaceTodoHTTPState.initialTodoID,
         "title": "Review Calculus notes", "content": "Prepare questions for the next seminar.",
         "priority": "medium", "completed": false,
         "dueAt": "2026-10-30T09:00:00+08:00", "createdAt": "2026-10-20T08:00:00+08:00",
         "updatedAt": "2026-10-20T08:00:00+08:00"],
        ["id": WorkspaceTodoHTTPState.completedTodoID,
         "title": "Read course syllabus", "content": NSNull(),
         "priority": "low", "completed": true,
         "dueAt": NSNull(), "createdAt": "2026-10-19T08:00:00+08:00",
         "updatedAt": "2026-10-20T08:00:00+08:00"],
    ]

    private var nextID = 3
    private static let timestamp = "2026-10-23T09:41:00+08:00"

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        if request.path == "/api/workspace/todos" {
            switch request.method {
            case "GET": return list(query: request.query)
            case "POST": return create(body: request.jsonBody)
            default: return (405, ["error": "Unsupported Todo method"])
            }
        }

        let prefix = "/api/workspace/todos/"
        guard request.path.hasPrefix(prefix) else { return nil }
        let id = String(request.path.dropFirst(prefix.count))
        guard !id.isEmpty, !id.contains("/") else { return nil }
        guard let index = todos.firstIndex(where: { $0["id"] as? String == id }) else {
            return (404, ["error": "Todo not found"])
        }
        switch request.method {
        case "PATCH":
            let body = request.jsonBody
            let fields = ["title", "content", "priority", "dueAt", "completed"]
            guard fields.contains(where: { body[$0] != nil }) else {
                return (400, ["error": "No changes"])
            }
            for field in fields {
                if let value = body[field] { todos[index][field] = value }
            }
            todos[index]["updatedAt"] = Self.timestamp
            return (200, ["success": true, "todo": todos[index]])
        case "DELETE":
            todos.remove(at: index)
            return (200, ["success": true])
        default:
            return (405, ["error": "Unsupported Todo method"])
        }
    }

    private func create(body: [String: Any]) -> (Int, Any) {
        guard let title = body["title"] as? String, !title.isEmpty else {
            return (400, ["error": "Title required"])
        }
        let id = String(format: "00000000-0000-4000-8000-%012d", nextID)
        nextID += 1
        todos.append([
            "id": id, "title": title, "content": body["content"] ?? NSNull(),
            "priority": body["priority"] ?? "medium", "completed": false,
            "dueAt": body["dueAt"] ?? NSNull(), "createdAt": Self.timestamp,
            "updatedAt": Self.timestamp,
        ])
        return (201, ["id": id])
    }

    private func list(query: [String: String]) -> (Int, Any) {
        let now = Self.date(Self.timestamp)!
        let counts = [
            "completed": todos.filter { $0["completed"] as? Bool == true }.count,
            "incomplete": todos.filter { $0["completed"] as? Bool == false }.count,
            "overdue": todos.filter {
                $0["completed"] as? Bool == false && Self.date($0["dueAt"]).map { $0 < now } == true
            }.count,
        ]
        let filtered = todos.filter { todo in
            if let completed = query["completed"],
               todo["completed"] as? Bool != (completed == "true") { return false }
            if let priority = query["priority"], todo["priority"] as? String != priority { return false }
            if let bound = Self.date(query["dueAfter"]),
               Self.date(todo["dueAt"]).map({ $0 >= bound }) != true { return false }
            if let bound = Self.date(query["dueBefore"]),
               Self.date(todo["dueAt"]).map({ $0 < bound }) != true { return false }
            return true
        }.sorted(by: Self.isOrderedBefore)

        guard query["page"] != nil || query["pageSize"] != nil else {
            let limit = Int(query["limit"] ?? "100") ?? 100
            return (200, ["counts": counts, "todos": Array(filtered.prefix(max(0, limit)))])
        }
        guard let page = Int(query["page"] ?? "1"), (1...100_000).contains(page),
              let pageSize = Int(query["pageSize"] ?? "20"), (1...100).contains(pageSize),
              query["limit"] == nil else {
            return (400, ["error": "Invalid Todo pagination"])
        }
        let start = min((page - 1) * pageSize, filtered.count)
        let end = min(start + pageSize, filtered.count)
        return (200, [
            "data": Array(filtered[start..<end]), "meta": ["counts": counts],
            "pagination": ["page": page, "pageSize": pageSize, "total": filtered.count,
                           "totalPages": (filtered.count + pageSize - 1) / pageSize],
        ])
    }

    private static func isOrderedBefore(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        let leftCompleted = lhs["completed"] as? Bool == true
        let rightCompleted = rhs["completed"] as? Bool == true
        if leftCompleted != rightCompleted { return !leftCompleted }
        let leftDue = date(lhs["dueAt"]) ?? .distantFuture
        let rightDue = date(rhs["dueAt"]) ?? .distantFuture
        if leftDue != rightDue { return leftDue < rightDue }
        let leftCreated = date(lhs["createdAt"]) ?? .distantPast
        let rightCreated = date(rhs["createdAt"]) ?? .distantPast
        if leftCreated != rightCreated { return leftCreated > rightCreated }
        return (lhs["id"] as? String ?? "") < (rhs["id"] as? String ?? "")
    }

    private static func date(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: string)
    }
}
