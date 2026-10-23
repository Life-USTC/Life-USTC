import Foundation

/// Mutable fixture state owned by the journey server's serial queue.
final class WorkspaceLearningHTTPState {
    static let pendingHomeworkID = "00000000-0000-4000-8001-000000000001"
    static let completedHomeworkID = "00000000-0000-4000-8001-000000000002"
    static let taHomeworkID = "00000000-0000-4000-8001-000000000003"
    static let datedExamID = 701
    static let undatedExamID = 702
    static let completedAt = "2026-10-23T02:03:04Z"

    let todoState: WorkspaceTodoHTTPState
    private(set) var homeworks: [[String: Any]]

    init(todoState: WorkspaceTodoHTTPState) {
        self.todoState = todoState
        homeworks = [
            Self.homework(Self.pendingHomeworkID, title: "Calculus problem set", completed: false),
            Self.homework(Self.completedHomeworkID, title: "Read the assignment guide", completed: true),
            Self.homework(Self.taHomeworkID, title: "Prepare tutorial materials", completed: false, requiresCompletion: false),
        ]
    }

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        if let response = todoState.response(to: request) { return response }
        switch (request.method, request.path) {
        case ("GET", "/api/workspace/homeworks"):
            return page(homeworks, query: request.query, defaultSize: 50)
        case ("GET", "/api/community/section-homeworks"):
            let response = page(homeworks, query: request.query, defaultSize: 50)
            guard var body = response.body as? [String: Any] else { return response }
            body["meta"] = ["viewer": ["userId": "fixture-student", "isAdmin": false]]
            return (response.status, body)
        case ("GET", "/api/workspace/exams"):
            let exams = Self.exams.filter { exam in
                if request.query["includeDateUnknown"] == "false", exam["examDate"] is NSNull { return false }
                guard let day = exam["examDate"] as? String else { return true }
                if let from = request.query["dateFrom"], String(day.prefix(10)) < String(from.prefix(10)) { return false }
                if let to = request.query["dateTo"], String(day.prefix(10)) > String(to.prefix(10)) { return false }
                return true
            }
            return page(exams, query: request.query, defaultSize: 100)
        case ("GET", "/api/workspace/overview/actionable"):
            return (200, overview(at: request.query["atTime"] ?? "2026-10-23T09:41:00+08:00"))
        case ("GET", "/api/workspace/calendar/events"):
            let events = ([scheduleEvent] + homeworkEvents + todoEvents + [examEvent]).filter { event in
                guard let at = event["at"] as? String else { return false }
                let day = String(at.prefix(10))
                if let from = request.query["dateFrom"], day < String(from.prefix(10)) { return false }
                if let to = request.query["dateTo"], day > String(to.prefix(10)) { return false }
                return true
            }
            return page(events, query: request.query, defaultSize: 100)
        default:
            break
        }

        let detailPrefix = "/api/community/section-homeworks/"
        if request.method == "GET", request.path.hasPrefix(detailPrefix) {
            let id = String(request.path.dropFirst(detailPrefix.count))
            guard let homework = homeworks.first(where: { $0["id"] as? String == id }) else {
                return (404, ["error": "Homework not found"])
            }
            return (200, ["homework": homework, "auditLogs": []])
        }
        let completionPrefix = "/api/workspace/homeworks/"
        let completionSuffix = "/completion"
        if request.method == "PUT", request.path.hasPrefix(completionPrefix), request.path.hasSuffix(completionSuffix) {
            let id = String(request.path.dropFirst(completionPrefix.count).dropLast(completionSuffix.count))
            guard let index = homeworks.firstIndex(where: { $0["id"] as? String == id }) else {
                return (404, ["error": "Homework not found"])
            }
            guard homeworks[index]["completionRequired"] as? Bool == true,
                  let completed = request.jsonBody["completed"] as? Bool else {
                return (400, ["error": "Homework does not accept this completion change"])
            }
            homeworks[index]["completion"] = completed ? ["completedAt": Self.completedAt] : NSNull()
            return (200, ["completed": completed, "completedAt": completed ? Self.completedAt as Any : NSNull()])
        }
        return nil
    }

    private func overview(at timestamp: String) -> [String: Any] {
        var focus = scheduleEvent
        focus["status"] = "now"
        let pending = homeworkEvents + todoEvents
        return [
            "anchor": ["atTime": timestamp, "dateFrom": "2026-10-23T00:00:00+08:00", "dateTo": "2026-10-31T00:00:00+08:00"],
            "focus": focus, "urgency": Array(homeworkEvents.prefix(1)),
            "upcoming": [examEvent] + todoEvents,
            "deadlines": ["today": pending.filter { ($0["at"] as? String)?.hasPrefix("2026-10-23") == true },
                          "nextThreeDays": homeworkEvents, "allPending": pending],
            "subscriptions": ["totalCount": 2, "currentSemesterCount": 2, "currentSemester": Self.semester],
        ]
    }

    private var scheduleEvent: [String: Any] {
        var event = Self.event(id: "schedule:901", type: "schedule", title: "Server-dated seminar",
                               at: "2026-10-23T08:15:00+08:00", target: "section", targetID: "42")
        event["endsAt"] = "2026-10-23T09:45:00+08:00"
        event["location"] = "East Campus 2201"
        event["teachers"] = ["Ada Teacher"]
        return event
    }

    private var homeworkEvents: [[String: Any]] {
        homeworks.filter { $0["completion"] is NSNull }.map { homework in
            let id = homework["id"] as! String
            var event = Self.event(id: "homework_due:\(id)", type: "homework_due", title: homework["title"] as! String,
                                   at: homework["submissionDueAt"] as? String, target: "homework", targetID: id)
            event["completionRequired"] = homework["completionRequired"]
            return event
        }
    }

    private var todoEvents: [[String: Any]] {
        todoState.todos.filter { $0["completed"] as? Bool == false }.map { todo in
            let id = todo["id"] as! String
            var event = Self.event(id: "todo_due:\(id)", type: "todo_due", title: todo["title"] as! String,
                                   at: todo["dueAt"] as? String, target: "todo", targetID: id)
            event["priority"] = todo["priority"]
            event["content"] = todo["content"]
            return event
        }
    }

    private var examEvent: [String: Any] {
        var event = Self.event(id: "exam:\(Self.datedExamID)", type: "exam", title: "Calculus examination",
                               at: "2026-12-23T09:00:00+08:00", target: "exam", targetID: String(Self.datedExamID))
        event["endsAt"] = "2026-12-23T11:00:00+08:00"
        event["location"] = "Exam Hall 1"
        event["examMode"] = "Closed book"
        return event
    }

    private static func event(id: String, type: String, title: String, at: String?, target: String, targetID: String) -> [String: Any] {
        ["id": id, "type": type, "title": title, "at": at.map { $0 as Any } ?? NSNull(),
         "endsAt": NSNull(), "location": NSNull(), "url": "/workspace", "youngId": NSNull(),
         "target": ["kind": target, "id": targetID], "hasTime": at != nil,
         "sectionJwId": 42, "sectionCode": "MATH101.01", "subscriptionKind": "regular"]
    }

    private func page(_ data: [[String: Any]], query: [String: String], defaultSize: Int) -> (status: Int, body: Any) {
        guard let number = Int(query["page"] ?? "1"), number > 0,
              let size = Int(query["pageSize"] ?? String(defaultSize)), (1...defaultSize).contains(size) else {
            return (400, ["error": "Invalid fixture pagination"])
        }
        let start = min((number - 1) * size, data.count)
        let end = min(start + size, data.count)
        return (200, ["data": Array(data[start..<end]),
                      "pagination": ["page": number, "pageSize": size, "total": data.count,
                                     "totalPages": (data.count + size - 1) / size]])
    }

    private static let semester: [String: Any] = [
        "id": 1, "jwId": 101, "code": "2026-FALL", "nameCn": "2026 Fall",
        "startDate": "2026-09-01T00:00:00+08:00", "endDate": "2027-01-31T00:00:00+08:00",
    ]

    private static let section: [String: Any] = [
        "id": 7, "jwId": 42, "code": "MATH101.01", "courseId": 11, "semesterId": 1,
        "course": ["id": 11, "jwId": 1001, "code": "MATH101", "nameCn": "Calculus", "nameEn": "Calculus"],
        "semester": semester,
    ]

    private static func homework(_ id: String, title: String, completed: Bool, requiresCompletion: Bool = true) -> [String: Any] {
        ["id": id, "sectionId": 7, "title": title, "isMajor": false, "requiresTeam": false,
         "completionRequired": requiresCompletion, "submissionDueAt": "2026-10-24T20:00:00+08:00",
         "publishedAt": "2026-10-20T08:00:00+08:00", "submissionStartAt": NSNull(),
         "createdAt": "2026-10-20T08:00:00+08:00", "updatedAt": "2026-10-22T08:00:00+08:00",
         "createdById": "fixture-student", "createdBy": ["id": "fixture-student", "name": "Fixture Student"],
         "updatedById": "fixture-editor", "updatedBy": ["id": "fixture-editor", "name": "Ada Teacher"],
         "description": ["id": "description-\(id)", "content": "Read the notes and complete the assigned exercises."],
         "section": section, "commentCount": 0,
         "completion": completed ? ["completedAt": completedAt] : NSNull()]
    }

    private static let exams: [[String: Any]] = [
        ["id": datedExamID, "jwId": 1701, "sectionId": 7, "examDate": "2026-12-23T00:00:00+08:00",
         "startTime": 900, "endTime": 1100, "examMode": "Closed book", "section": section,
         "examRooms": [["id": 801, "room": "Exam Hall 1"]]],
        ["id": undatedExamID, "jwId": 1702, "sectionId": 7, "examDate": NSNull(),
         "startTime": NSNull(), "endTime": NSNull(), "examMode": "To be announced", "section": section,
         "examRooms": [["id": 802, "room": "Exam Hall 2"]]],
    ]
}
