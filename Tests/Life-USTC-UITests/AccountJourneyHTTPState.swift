import Foundation

final class AccountJourneyHTTPState {
    static let cursor = "2026-10-23T01:41:00.000Z|activity-first"
    private var visitedProfile = false

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        if request.method == "GET", request.path.hasPrefix("/account/settings/") || request.path == "/admin" {
            if request.path == "/account/settings/profile" { visitedProfile = true }
            return (200, ["message": "Account website fixture", "path": request.path])
        }
        switch (request.method, request.path) {
        case ("GET", "/api/account/profile"):
            return (200, ["id": "fixture-student", "name": visitedProfile ? "Updated Fixture Student" : "Fixture Student",
                          "username": "fixture-student", "email": NSNull(), "image": NSNull(), "isAdmin": NSNull()])
        case ("GET", "/api/account/client-activity"):
            guard request.headers["authorization"] == "Bearer \(ServerJourneyHTTPFixture.token)",
                  request.query["limit"] == "30" else {
                return (401, ["error": "Expected current app authorization"])
            }
            if let cursor = request.query["cursor"] {
                guard cursor == Self.cursor else { return (400, ["error": "Expected opaque cursor unchanged"]) }
                return (200, ["items": [activity("activity-second", action: "upload_delete", outcome: "denied")],
                              "nextCursor": NSNull()])
            }
            return (200, ["items": [activity("activity-first", action: "comment_create", outcome: "success")],
                          "nextCursor": Self.cursor])
        default: return nil
        }
    }

    private func activity(_ id: String, action: String, outcome: String) -> [String: Any] {
        ["id": id, "action": action, "outcome": outcome, "channel": "rest",
         "createdAt": "2026-10-23T09:41:00+08:00", "targetType": "Comment"]
    }
}
