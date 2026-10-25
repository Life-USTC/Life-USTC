import Foundation

/// Fixed public discovery records with independent filter decoys.
final class PublicDiscoveryHTTPState {
    static let scienceOrganizer = "fixture-organizer-m4"
    static let artsOrganizer = "fixture-organizer-arts"

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        guard request.method == "GET" else { return nil }
        if request.path == "/api/catalog/young-events" {
            let query = request.query
            if query["dateUnknown"] == "true" && (query["dateFrom"] != nil || query["dateTo"] != nil) {
                return (400, ["error": "Unknown-date filtering cannot be combined with date bounds"])
            }
            let matching = events.filter { event in
                if let search = query["search"],
                   !(event["name"] as! String).localizedCaseInsensitiveContains(search) { return false }
                for key in ["category", "module", "activityLevel", "organizerId"] {
                    if let value = query[key], event[key] as? String != value { return false }
                }
                if let active = query["active"], event["isActive"] as? Bool != (active == "true") { return false }
                return true
            }
            let startKey = query["timeBasis"] == "registration" ? "applyStartAt" : "startAt"
            let endKey = query["timeBasis"] == "registration" ? "applyEndAt" : "endAt"
            let unknown = matching.filter { $0[startKey] == nil }
            let formatter = ISO8601DateFormatter()
            let from = query["dateFrom"].flatMap { formatter.date(from: "\($0)T00:00:00+08:00") }
            let to = query["dateTo"].flatMap { formatter.date(from: "\($0)T23:59:59+08:00") }
            let dated = matching.filter { event in
                guard from != nil || to != nil else { return true }
                guard let text = event[startKey] as? String, let start = formatter.date(from: text) else { return false }
                if let to, start > to { return false }
                let end = (event[endKey] as? String).flatMap { formatter.date(from: $0) }
                if let from, start < from && (end == nil || end! <= from) { return false }
                return true
            }
            let selected = query["dateUnknown"] == "true" ? unknown : dated
            var response = page(selected, request: request)
            response["meta"] = ["unknownDateCount": unknown.count,
                                "source": ["status": "fresh", "lastSyncedAt": "2026-10-23T10:30:00+08:00"]]
            return (200, response)
        }
        if request.path == "/api/catalog/young-organizers" {
            let rows: [[String: Any]] = [
                ["id": Self.artsOrganizer, "name": "Student Arts Association", "normalizedName": "student arts association", "totalCount": 2,
                 "activeCount": 2, "upcomingCount": 0, "historyCount": 0],
                ["id": Self.scienceOrganizer, "name": "Student Science Association", "normalizedName": "student science association", "totalCount": 5,
                 "activeCount": 3, "upcomingCount": 2, "historyCount": 0],
            ]
            return (200, page(rows, request: request))
        }
        let prefix = "/api/catalog/young-events/"
        if request.path.hasPrefix(prefix),
           let event = events.first(where: { $0["youngId"] as? String == String(request.path.dropFirst(prefix.count)) }) {
            return (200, event)
        }
        return nil
    }

    private var events: [[String: Any]] {
        [
            event("fixture-young-m4", "Science Communication Workshop", module: "智", level: "校级"),
            event("fixture-young-alumni", "Science Alumni Forum", module: "智", level: "校级", active: false),
            event("fixture-young-arts", "Arts Practice Workshop", category: "Arts workshop", module: "美", level: "院级", organizer: Self.artsOrganizer),
            event("fixture-young-future", "Future Creative Session", module: "未来模块", level: "国际级"),
            event("fixture-young-science-undated", "Science Undated Workshop", module: "智", level: "校级", dated: false),
            event("fixture-young-music-undated", "Music Undated Circle", category: "Arts workshop", module: "美", level: "校级", organizer: Self.artsOrganizer, dated: false),
            event("fixture-young-unlisted-undated", "Science Unlisted Seminar", module: "智", level: "校级", active: false, dated: false),
        ]
    }

    private func event(
        _ id: String, _ name: String, category: String = "Campus workshop", module: String,
        level: String, organizer: String = scienceOrganizer, active: Bool = true, dated: Bool = true
    ) -> [String: Any] {
        var value: [String: Any] = [
            "youngId": id, "name": name, "category": category, "module": module, "activityLevel": level,
            "organizerId": organizer,
            "organizer": organizer == Self.scienceOrganizer ? "Student Science Association" : "Student Arts Association",
            "isActive": active, "sourceMissing": false, "dateUnknown": !dated,
            "status": "Registration starts soon", "location": "East Campus Student Activity Center",
            "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
            "signupDepartmentIds": [], "allowedAttachmentTypes": [],
        ]
        if dated {
            value["startAt"] = "2035-09-16T09:00:00+08:00"
            value["endAt"] = "2035-09-16T11:00:00+08:00"
            value["applyStartAt"] = "2035-09-10T09:00:00+08:00"
            value["applyEndAt"] = "2035-09-15T18:00:00+08:00"
        }
        return value
    }

    private func page(_ rows: [[String: Any]], request: ServerJourneyHTTPFixture.Request) -> [String: Any] {
        let page = Int(request.query["page"] ?? "1") ?? 1
        let size = Int(request.query["pageSize"] ?? "100") ?? 100
        let start = min(rows.count, max(0, (page - 1) * size))
        let end = min(rows.count, start + size)
        return ["data": Array(rows[start..<end]),
                "pagination": ["page": page, "pageSize": size, "total": rows.count,
                               "totalPages": rows.isEmpty ? 0 : (rows.count + size - 1) / size]]
    }
}
