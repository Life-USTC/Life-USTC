import Foundation

/// Stateful community wire responses used by native UI journeys.
final class CommunityHTTPState {
    static let commentID = "00000000-0000-4000-8002-000000000001"
    static let uploadID = "00000000-0000-4000-8003-000000000001"
    static let homeworkID = "00000000-0000-4000-8004-000000000001"
    static let timestamp = "2026-10-23T02:03:04Z"
    private(set) var comments: [[String: Any]] = []
    private(set) var homeworks: [[String: Any]] = []
    private(set) var uploads: [[String: Any]] = []
    private var descriptionText = "Shared seminar preparation notes."
    private var descriptionHistory: [[String: Any]] = []
    private var audits: [[String: Any]] = []
    private var hiddenComments = 0

    init() {
        uploads = [["id": Self.uploadID, "key": "fixture/notes.txt", "filename": "Seminar notes.txt",
                    "size": 38, "createdAt": Self.timestamp]]
        comments = [comment(id: Self.commentID, body: "Bring your questions to the seminar.", attachments: [attachment])]
        homeworks = [homework(id: Self.homeworkID, title: "Seminar preparation")]
    }

    func hideAllComments() {
        hiddenComments = comments.count
        comments = []
    }

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        let path = request.path
        let body = request.jsonBody
        let signedIn = request.headers["authorization"] == "Bearer \(ServerJourneyHTTPFixture.token)"
        switch (request.method, path) {
        case ("GET", "/api/community/comments"):
            guard request.query["targetType"] == "section", request.query["targetId"] == "7",
                  request.query["sectionId"] == nil else { return (400, ["error": "Expected internal section target ID 7"]) }
            return (200, page(comments, request: request, meta: ["hiddenCount": hiddenComments, "viewer": viewer(signedIn),
                                                               "target": ["type": "section", "targetId": 7]]))
        case ("POST", "/api/community/comments"):
            guard signedIn, body["targetType"] as? String == "section",
                  body["sectionJwId"] as? Int == 42 || body["targetId"] as? String == "7"
            else { return (400, ["error": "Expected section comment target"]) }
            let id = "00000000-0000-4000-8002-\(String(format: "%012d", comments.count + 2))"
            var created = comment(id: id, body: body["body"] as? String ?? "")
            created["visibility"] = body["visibility"] ?? "public"
            created["isAnonymous"] = body["isAnonymous"] ?? false
            if let parent = body["parentId"] as? String,
               let index = comments.firstIndex(where: { $0["id"] as? String == parent }) {
                created["parentId"] = parent
                comments[index]["replies"] = [created]
            } else { comments.append(created) }
            return (201, ["id": id])
        case ("GET", "/api/community/descriptions"):
            return (200, ["description": ["id": "fixture-description", "content": descriptionText,
                                            "renderedHtml": "<p>\(descriptionText)</p>", "updatedAt": Self.timestamp,
                                            "lastEditedAt": Self.timestamp, "lastEditedBy": actor],
                          "history": descriptionHistory, "viewer": viewer(signedIn)])
        case ("POST", "/api/community/descriptions"):
            guard signedIn, let content = body["content"] as? String else { return (400, ["error": "Missing content"]) }
            descriptionHistory.insert(["id": "fixture-edit-\(descriptionHistory.count + 1)", "createdAt": Self.timestamp,
                                       "previousContent": descriptionText, "nextContent": content, "editor": actor], at: 0)
            descriptionText = content
            return (200, ["id": "fixture-description", "updated": true])
        case ("GET", "/api/community/section-homeworks"):
            return (200, page(homeworks, request: request, meta: ["viewer": viewer(signedIn)]))
        case ("POST", "/api/community/section-homeworks"):
            guard signedIn, body["sectionJwId"] as? Int == 42 else { return (400, ["error": "Expected section JW ID 42"]) }
            let id = "00000000-0000-4000-8004-\(String(format: "%012d", homeworks.count + 1))"
            var created = homework(id: id, title: body["title"] as? String ?? "")
            updateHomework(&created, body: body)
            homeworks.append(created)
            appendAudit(created, action: "created")
            return (201, ["id": id, "homework": created])
        case ("GET", "/api/community/section-homeworks/audit"):
            return (200, ["auditLogs": audits])
        case ("GET", "/api/workspace/uploads"):
            return (200, page(uploads, request: request, meta: quota))
        case ("GET", "/api/community/users/fixture-student"):
            return (200, ["user": ["id": "fixture-student", "username": "fixture-student", "name": "Fixture Student",
                                    "image": NSNull(), "createdAt": "2025-09-01T00:00:00Z",
                                    "_count": ["comments": 12, "uploads": 1, "homeworksCreated": 3]],
                          "weeks": [[ ["date": "2026-10-22", "count": 2], ["date": "2026-10-23", "count": 3] ]],
                          "totalContributions": 16])
        default: break
        }
        if path.hasPrefix("/api/community/comments/") {
            let id = String(path.dropFirst("/api/community/comments/".count))
            guard let index = comments.firstIndex(where: { $0["id"] as? String == id }) else {
                return (404, ["error": "Comment missing"])
            }
            switch request.method {
            case "GET": return (200, ["thread": [comments[index]], "focusId": id, "hiddenCount": 0,
                                       "viewer": viewer(signedIn), "target": ["sectionId": 7]])
            case "PATCH":
                comments[index]["body"] = body["body"]
                comments[index]["visibility"] = body["visibility"] ?? "public"
                if let ids = body["attachmentIds"] as? [String] { comments[index]["attachments"] = ids.contains(Self.uploadID) ? [attachment] : [] }
                return (200, ["success": true, "comment": comments[index]])
            case "DELETE": comments.remove(at: index); return (200, ["success": true])
            default: return nil
            }
        }
        if path.hasPrefix("/api/community/section-homeworks/") {
            let id = String(path.dropFirst("/api/community/section-homeworks/".count))
            guard let index = homeworks.firstIndex(where: { $0["id"] as? String == id }) else { return nil }
            switch request.method {
            case "GET": return (200, ["homework": homeworks[index], "auditLogs": audits.filter { $0["homeworkId"] as? String == id }])
            case "PATCH":
                updateHomework(&homeworks[index], body: body)
                appendAudit(homeworks[index], action: "updated")
                return (200, ["success": true, "homework": homeworks[index]])
            case "DELETE":
                homeworks[index]["deletedAt"] = Self.timestamp
                appendAudit(homeworks[index], action: "deleted")
                return (200, ["success": true])
            default: return nil
            }
        }
        if path.hasPrefix("/api/workspace/uploads/") {
            if path.hasSuffix("/download") { return (200, Data("Seminar preparation notes from fixture.\n".utf8)) }
            let id = String(path.dropFirst("/api/workspace/uploads/".count))
            guard let index = uploads.firstIndex(where: { $0["id"] as? String == id }) else { return (404, ["error": "File missing"]) }
            if request.method == "PATCH" {
                uploads[index]["filename"] = body["filename"]
                return (200, ["upload": uploads[index]])
            }
            if request.method == "DELETE" {
                let removed = uploads.remove(at: index)
                return (200, ["deletedId": id, "deletedSize": removed["size"] ?? 0])
            }
        }
        return nil
    }

    private var actor: [String: Any] { ["id": "fixture-student", "name": "Fixture Student", "username": "fixture-student", "image": NSNull()] }
    private var quota: [String: Any] { ["maxFileSizeBytes": 10_485_760, "quotaBytes": 104_857_600, "usedBytes": uploads.isEmpty ? 0 : 38] }
    private var attachment: [String: Any] {
        ["id": "fixture-attachment", "uploadId": Self.uploadID, "filename": "Seminar notes.txt",
         "url": "/api/workspace/uploads/\(Self.uploadID)/download", "contentType": "text/plain", "size": 38]
    }
    private func viewer(_ authenticated: Bool) -> [String: Any] {
        ["userId": authenticated ? "fixture-student" as Any : NSNull(), "isAdmin": false,
         "isAuthenticated": authenticated, "isSuspended": false]
    }
    private func page(_ data: [[String: Any]], request: ServerJourneyHTTPFixture.Request, meta: [String: Any]) -> [String: Any] {
        let size = Int(request.query["pageSize"] ?? "100") ?? 100
        return ["data": Array(data.prefix(size)), "pagination": ["page": 1, "pageSize": size, "total": data.count,
                                                                  "totalPages": data.isEmpty ? 0 : (data.count + size - 1) / size], "meta": meta]
    }
    private func comment(id: String, body: String, attachments: [[String: Any]] = []) -> [String: Any] {
        ["id": id, "body": body, "visibility": "public", "status": "active", "isAnonymous": false,
         "createdAt": Self.timestamp, "updatedAt": Self.timestamp, "author": actor,
         "reactions": [], "replies": [], "attachments": attachments,
         "canReact": true, "canReply": true, "canEdit": true, "canDelete": true, "isAuthor": true]
    }
    private func homework(id: String, title: String) -> [String: Any] {
        ["id": id, "sectionId": 7, "title": title, "isMajor": false, "requiresTeam": false,
         "completionRequired": true, "createdAt": Self.timestamp, "updatedAt": Self.timestamp,
         "createdById": "fixture-student", "createdBy": actor, "deletedAt": NSNull(),
         "description": ["id": "fixture-hw-description", "content": "Prepare one question for discussion."],
         "section": ["id": 7, "jwId": 42, "code": "MATH101.01", "courseId": 11,
                     "course": ["id": 11, "jwId": 1001, "code": "MATH101", "nameCn": "Calculus"]]]
    }
    private func updateHomework(_ homework: inout [String: Any], body: [String: Any]) {
        for key in ["title", "isMajor", "requiresTeam", "dueAt", "examAt", "startAt", "endAt"] {
            if let value = body[key] { homework[key] = value }
        }
        if let text = body["description"] as? String { homework["description"] = ["id": "fixture-hw-description", "content": text] }
    }
    private func appendAudit(_ homework: [String: Any], action: String) {
        audits.insert(["id": "fixture-audit-\(audits.count + 1)", "action": action, "createdAt": Self.timestamp,
                       "titleSnapshot": homework["title"] ?? "", "sectionId": 7,
                       "homeworkId": homework["id"] ?? "", "actorId": "fixture-student", "actor": actor], at: 0)
    }
}
