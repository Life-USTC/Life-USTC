import Foundation

/// Two complete wire pages with a second response released by the test.
final class YoungIncrementalHTTPState {
    static let firstTitle = "First batch workshop"
    static let finalTitle = "Final batch workshop"
    var holdsSecondPage = true

    func shouldHold(_ request: ServerJourneyHTTPFixture.Request) -> Bool {
        holdsSecondPage && request.method == "GET" && request.path == "/api/catalog/young-events"
            && request.query["page"] == "2"
    }

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        guard request.method == "GET", request.path == "/api/catalog/young-events" else { return nil }
        guard request.query["pageSize"] == "100", let page = Int(request.query["page"] ?? ""),
              (1...2).contains(page)
        else { return (400, ["error": "Expected a 100-row activity page at page 1 or 2"]) }
        let day = request.query["dateFrom"] ?? "2026-10-25"
        let indices = page == 1 ? Array(1...100) : [101]
        return (200, [
            "data": indices.map { event($0, day: day) },
            "pagination": ["page": page, "pageSize": 100, "total": 101, "totalPages": 2],
            "meta": ["unknownDateCount": 0,
                     "source": ["status": "fresh", "lastSyncedAt": "2026-10-25T08:00:00+08:00"]],
        ])
    }

    private func event(_ index: Int, day: String) -> [String: Any] {
        let title = index == 1 ? Self.firstTitle : index == 101 ? Self.finalTitle : "Additional activity \(index)"
        let hour = index == 1 ? "09" : index == 101 ? "11" : "10"
        return [
            "youngId": "fixture-incremental-\(index)", "name": title,
            "category": "Campus workshop", "organizer": "Student Science Association",
            "isActive": true, "dateUnknown": false, "sourceMissing": false,
            "startAt": "\(day)T\(hour):00:00+08:00", "endAt": "\(day)T\(hour):30:00+08:00",
            "upstreamOrganizerIds": [], "upstreamSponsorIds": [], "tagIds": [],
            "signupDepartmentIds": [], "allowedAttachmentTypes": [],
        ]
    }
}
