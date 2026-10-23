import Foundation

/// Stateful Young and publication wire responses for native UI journeys.
final class YoungCampusHTTPState {
    static let eventID = "fixture-young-m4"
    static let organizerID = "fixture-organizer-m4"
    static let notificationID = "fixture-young-notice-m4"
    static let publicationID = "fixture-publication-m4"
    static let siblingID = "fixture-publication-sibling"
    static let timestamp = "2026-10-23T10:30:00+08:00"
    private let fixtures: [String: Any]
    private var eventSubscribed = true
    private var organizerFollowed = true
    private var remindSignup = true
    private var remindDeadline = false
    private var remindStart = true
    private var notificationRead = false

    init() {
        fixtures = try! JSONSerialization.jsonObject(with: Data(Self.fixtureJSON.utf8)) as! [String: Any]
    }

    func response(to request: ServerJourneyHTTPFixture.Request) -> (status: Int, body: Any)? {
        let path = request.path
        let body = request.jsonBody
        let signedIn = request.headers["authorization"] == "Bearer \(ServerJourneyHTTPFixture.token)"
        if path.hasPrefix("/api/workspace/young-") && !signedIn {
            return (401, ["error": "Sign in required"])
        }
        switch (request.method, path) {
        case ("GET", "/api/catalog/young-events"):
            var response = fixtures["GET \(path)"] as! [String: Any]
            var event = eventRecord
            if let day = request.query["dateFrom"] {
                event["startAt"] = "\(day)T09:00:00+08:00"
                event["endAt"] = "\(day)T11:00:00+08:00"
            }
            response["data"] = [event]
            return (200, response)
        case ("GET", "/api/workspace/calendar/events"):
            guard signedIn else { return (401, ["error": "Sign in required"]) }
            let day = request.query["dateFrom"] ?? "2026-10-23"
            let occupied: [String: Any] = ["id": "schedule:fixture-conflict", "type": "schedule",
                "title": "Morning seminar", "at": "\(day)T08:15:00+08:00", "endsAt": "\(day)T09:45:00+08:00",
                "url": "/catalog/sections/42", "location": "East Campus", "youngId": NSNull()]
            return (200, page([occupied], request: request))
        case ("GET", "/api/workspace/young-event-subscriptions"):
            var subscription = eventState
            subscription.removeValue(forKey: "subscribed")
            subscription["createdAt"] = Self.timestamp
            subscription["event"] = eventRecord
            return (200, page(eventSubscribed ? [subscription] : [], request: request))
        case ("GET", "/api/workspace/young-event-subscriptions/\(Self.eventID)"):
            return (200, eventState)
        case ("PUT", "/api/workspace/young-event-subscriptions/\(Self.eventID)"):
            guard let subscribed = body["subscribed"] as? Bool else { return (400, ["error": "Missing subscription flag"]) }
            eventSubscribed = subscribed
            remindSignup = subscribed && (body["remindSignup"] as? Bool ?? true)
            remindDeadline = subscribed && (body["remindDeadline"] as? Bool ?? true)
            remindStart = subscribed && (body["remindStart"] as? Bool ?? true)
            return (200, eventState)
        case ("GET", "/api/workspace/young-organizer-subscriptions"):
            let subscription: [String: Any] = ["organizerId": Self.organizerID, "createdAt": Self.timestamp,
                "organizer": ["id": Self.organizerID, "name": "Student Science Association"]]
            return (200, page(organizerFollowed ? [subscription] : [], request: request))
        case ("GET", "/api/workspace/young-organizer-subscriptions/\(Self.organizerID)"):
            return (200, ["organizerId": Self.organizerID, "subscribed": organizerFollowed])
        case ("PUT", "/api/workspace/young-organizer-subscriptions/\(Self.organizerID)"):
            guard let subscribed = body["subscribed"] as? Bool else { return (400, ["error": "Missing follow flag"]) }
            organizerFollowed = subscribed
            return (200, ["organizerId": Self.organizerID, "subscribed": organizerFollowed])
        case ("GET", "/api/workspace/young-notifications"):
            let original = fixtures["GET \(path)"] as! [String: Any]
            var rows = original["data"] as! [[String: Any]]
            if notificationRead { rows[0]["readAt"] = Self.timestamp }
            if !eventSubscribed || (notificationRead && request.query["unread"] == "true") { rows = [] }
            return (200, page(rows, request: request))
        case ("POST", "/api/workspace/young-notifications/\(Self.notificationID)/read"):
            notificationRead = true
            return (200, ["id": Self.notificationID, "success": true])
        case ("GET", "/api/community/comments") where request.query["targetType"] == "young-event":
            var response = page([], request: request)
            response["meta"] = ["hiddenCount": 0, "viewer": ["userId": signedIn ? "fixture-student" as Any : NSNull(),
                "isAuthenticated": signedIn, "isAdmin": false, "isSuspended": false],
                "target": ["type": "young-event", "youngId": Self.eventID, "youngEventName": "Science Communication Workshop"]]
            return (200, response)
        case ("GET", "/api/publications"):
            let original = fixtures["GET \(path)"] as! [String: Any]
            var rows = original["data"] as! [[String: Any]]
            if request.query["type"] == "notice" { rows = [] }
            if request.query["source"] == "student-office", !rows.isEmpty {
                let detail = fixtures["GET /api/publications/\(Self.siblingID)"] as! [String: Any]
                rows[0]["id"] = Self.siblingID
                rows[0]["source"] = detail["source"]
            }
            return (200, page(rows, request: request))
        default:
            if let fixture = fixtures["\(request.method) \(path)"] { return (200, fixture) }
            return nil
        }
    }

    private var eventRecord: [String: Any] {
        fixtures["GET /api/catalog/young-events/\(Self.eventID)"] as! [String: Any]
    }

    private var eventState: [String: Any] {
        ["youngId": Self.eventID, "subscribed": eventSubscribed, "remindSignup": remindSignup,
         "remindDeadline": remindDeadline, "remindStart": remindStart]
    }

    private func page(_ data: [[String: Any]], request: ServerJourneyHTTPFixture.Request) -> [String: Any] {
        let size = Int(request.query["pageSize"] ?? "100") ?? 100
        return ["data": data, "pagination": ["page": 1, "pageSize": size, "total": data.count,
                                               "totalPages": data.isEmpty ? 0 : 1]]
    }

    private static let fixtureJSON = #"""
{
  "GET /api/catalog/young-events": {
    "data": [
      {
        "youngId": "fixture-young-m4",
        "name": "Science Communication Workshop",
        "category": "Campus workshop",
        "organizer": "Student Science Association",
        "organizerId": "fixture-organizer-m4",
        "status": "Registration starts soon",
        "isActive": true,
        "sourceMissing": false,
        "dateUnknown": false,
        "upstreamOrganizerIds": [],
        "upstreamSponsorIds": [],
        "tagIds": [],
        "signupDepartmentIds": [],
        "allowedAttachmentTypes": [],
        "description": "Practice explaining research to a general audience.",
        "location": "East Campus Student Activity Center",
        "startAt": "2035-09-16T09:00:00+08:00",
        "endAt": "2035-09-16T11:00:00+08:00",
        "applyStartAt": "2035-09-10T09:00:00+08:00",
        "applyEndAt": "2035-09-15T18:00:00+08:00",
        "capacity": 30,
        "appliedCount": null,
        "hours": 2
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 100,
      "total": 1,
      "totalPages": 1
    },
    "unknownDateCount": 0,
    "source": {
      "status": "fresh",
      "lastSyncedAt": "2026-10-23T10:30:00+08:00"
    }
  },
  "GET /api/catalog/young-events/fixture-young-m4": {
    "youngId": "fixture-young-m4",
    "name": "Science Communication Workshop",
    "category": "Campus workshop",
    "organizer": "Student Science Association",
    "organizerId": "fixture-organizer-m4",
    "status": "Registration starts soon",
    "isActive": true,
    "sourceMissing": false,
    "dateUnknown": false,
    "upstreamOrganizerIds": [],
    "upstreamSponsorIds": [],
    "tagIds": [],
    "signupDepartmentIds": [],
    "allowedAttachmentTypes": [],
    "description": "Practice explaining research to a general audience.",
    "location": "East Campus Student Activity Center",
    "startAt": "2035-09-16T09:00:00+08:00",
    "endAt": "2035-09-16T11:00:00+08:00",
    "applyStartAt": "2035-09-10T09:00:00+08:00",
    "applyEndAt": "2035-09-15T18:00:00+08:00",
    "capacity": 30,
    "appliedCount": null,
    "hours": 2
  },
  "GET /api/catalog/young-organizers": {
    "data": [
      {
        "id": "fixture-organizer-m4",
        "name": "Student Science Association",
        "normalizedName": "student-science-association",
        "totalCount": 1,
        "activeCount": 1,
        "upcomingCount": 0,
        "historyCount": 0
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 100,
      "total": 1,
      "totalPages": 1
    }
  },
  "GET /api/catalog/young-organizers/fixture-organizer-m4": {
    "id": "fixture-organizer-m4",
    "name": "Student Science Association",
    "normalizedName": "student-science-association",
    "totalCount": 1,
    "activeCount": 1,
    "upcomingCount": 0,
    "historyCount": 0
  },
  "GET /api/workspace/young-event-subscriptions": {
    "data": [
      {
        "youngId": "fixture-young-m4",
        "createdAt": "2026-10-23T10:30:00+08:00",
        "remindSignup": true,
        "remindDeadline": false,
        "remindStart": true,
        "event": {
          "youngId": "fixture-young-m4",
          "name": "Science Communication Workshop",
          "category": "Campus workshop",
          "organizer": "Student Science Association",
          "organizerId": "fixture-organizer-m4",
          "status": "Registration starts soon",
          "isActive": true,
          "sourceMissing": false,
          "dateUnknown": false,
          "upstreamOrganizerIds": [],
          "upstreamSponsorIds": [],
          "tagIds": [],
          "signupDepartmentIds": [],
          "allowedAttachmentTypes": [],
          "description": "Practice explaining research to a general audience.",
          "location": "East Campus Student Activity Center",
          "startAt": "2035-09-16T09:00:00+08:00",
          "endAt": "2035-09-16T11:00:00+08:00",
          "applyStartAt": "2035-09-10T09:00:00+08:00",
          "applyEndAt": "2035-09-15T18:00:00+08:00",
          "capacity": 30,
          "appliedCount": null,
          "hours": 2
        }
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 100,
      "total": 1,
      "totalPages": 1
    }
  },
  "GET /api/workspace/young-event-subscriptions/fixture-young-m4": {
    "youngId": "fixture-young-m4",
    "subscribed": true,
    "remindSignup": true,
    "remindDeadline": false,
    "remindStart": true
  },
  "GET /api/workspace/young-organizer-subscriptions": {
    "data": [
      {
        "organizerId": "fixture-organizer-m4",
        "createdAt": "2026-10-23T10:30:00+08:00",
        "organizer": {
          "id": "fixture-organizer-m4",
          "name": "Student Science Association"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 100,
      "total": 1,
      "totalPages": 1
    }
  },
  "GET /api/workspace/young-organizer-subscriptions/fixture-organizer-m4": {
    "organizerId": "fixture-organizer-m4",
    "subscribed": true
  },
  "GET /api/workspace/young-notifications": {
    "data": [
      {
        "id": "fixture-young-notice-m4",
        "youngId": "fixture-young-m4",
        "kind": "event_start",
        "title": "Workshop reminder",
        "body": "Event starts soon",
        "createdAt": "2026-10-23T10:30:00+08:00",
        "readAt": null,
        "expiresAt": null
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 100,
      "total": 1,
      "totalPages": 1
    }
  },
  "GET /api/publications": {
    "data": [
      {
        "id": "fixture-publication-m4",
        "canonicalUrl": "https://news.ustc.edu.cn/article",
        "publicationType": "news",
        "source": {
          "id": "ustc-news",
          "name": "USTC News",
          "organizationLevel": "university"
        },
        "revision": {
          "id": "publication-revision",
          "revisionHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "observedAt": "2026-10-23T10:30:00+08:00",
          "title": "Autumn Science Festival",
          "author": "Campus Newsroom",
          "reporter": null,
          "editor": null,
          "originalPublisher": "University News Center",
          "publishedAt": "2026-10-22T09:00:00+08:00",
          "updatedAtSource": null,
          "category": "Campus",
          "summary": "Lectures, workshops, and open laboratories across campus.",
          "sourcePageUrl": "https://news.ustc.edu.cn/article"
        },
        "objects": []
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 1,
      "totalPages": 1
    }
  },
  "GET /api/publications/fixture-publication-m4": {
    "id": "fixture-publication-m4",
    "canonicalUrl": "https://news.ustc.edu.cn/article",
    "publicationType": "news",
    "source": {
      "id": "ustc-news",
      "name": "USTC News",
      "organizationLevel": "university"
    },
    "revision": {
      "id": "publication-revision",
      "revisionHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "observedAt": "2026-10-23T10:30:00+08:00",
      "title": "Autumn Science Festival",
      "author": "Campus Newsroom",
      "reporter": null,
      "editor": null,
      "originalPublisher": "University News Center",
      "publishedAt": "2026-10-22T09:00:00+08:00",
      "updatedAtSource": null,
      "category": "Campus",
      "summary": "Lectures, workshops, and open laboratories across campus.",
      "sourcePageUrl": "https://news.ustc.edu.cn/article",
      "images": [],
      "bodyMarkdown": "# Autumn Science Festival\n\nExplore **open laboratories**, join student workshops, and meet researchers.\n\nThe full schedule is available in the attached program.",
      "bodyText": "Do not replace the Markdown body.",
      "extractionMethod": null,
      "classifierVersion": null,
      "objects": [
        {
          "kind": "asset",
          "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "size": 1234,
          "contentType": "application/pdf",
          "status": "verified",
          "url": "/api/publications/objects/asset/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "sortOrder": 0,
          "altText": null,
          "filename": "festival-program.pdf",
          "sourceUrl": null
        }
      ]
    },
    "alsoPublishedIn": [
      {
        "id": "fixture-publication-sibling",
        "canonicalUrl": "https://office.ustc.edu.cn/article",
        "source": {
          "id": "student-office",
          "name": "Student Office",
          "organizationLevel": "office"
        },
        "publishedAt": "2026-10-22T09:00:00+08:00"
      }
    ]
  },
  "GET /api/publications/fixture-publication-sibling": {
    "id": "fixture-publication-sibling",
    "canonicalUrl": "https://news.ustc.edu.cn/article",
    "publicationType": "news",
    "source": {
      "id": "student-office",
      "name": "Student Office",
      "organizationLevel": "office"
    },
    "revision": {
      "id": "publication-revision",
      "revisionHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "observedAt": "2026-10-23T10:30:00+08:00",
      "title": "Autumn Science Festival",
      "author": "Campus Newsroom",
      "reporter": null,
      "editor": null,
      "originalPublisher": "University News Center",
      "publishedAt": "2026-10-22T09:00:00+08:00",
      "updatedAtSource": null,
      "category": "Campus",
      "summary": "Lectures, workshops, and open laboratories across campus.",
      "sourcePageUrl": "https://news.ustc.edu.cn/article",
      "images": [],
      "bodyMarkdown": "# Autumn Science Festival\n\nExplore **open laboratories**, join student workshops, and meet researchers.\n\nThe full schedule is available in the attached program.",
      "bodyText": "Do not replace the Markdown body.",
      "extractionMethod": null,
      "classifierVersion": null,
      "objects": [
        {
          "kind": "asset",
          "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "size": 1234,
          "contentType": "application/pdf",
          "status": "verified",
          "url": "/api/publications/objects/asset/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "sortOrder": 0,
          "altText": null,
          "filename": "festival-program.pdf",
          "sourceUrl": null
        }
      ]
    },
    "alsoPublishedIn": []
  },
  "GET /api/publications/sources": {
    "groups": [
      {
        "organizationLevel": "university",
        "sourceCount": 1,
        "publicationCount": 1,
        "sources": [
          {
            "id": "ustc-news",
            "name": "USTC News",
            "organizationLevel": "university",
            "hosts": [
              "news.ustc.edu.cn"
            ],
            "publicationCount": 1,
            "lastPublishedAt": "2026-10-22T09:00:00+08:00"
          }
        ]
      },
      {
        "organizationLevel": "office",
        "sourceCount": 1,
        "publicationCount": 1,
        "sources": [
          {
            "id": "student-office",
            "name": "Student Office",
            "organizationLevel": "office",
            "hosts": [
              "office.ustc.edu.cn"
            ],
            "publicationCount": 1,
            "lastPublishedAt": "2026-10-22T09:00:00+08:00"
          }
        ]
      }
    ],
    "totals": {
      "sourceCount": 2,
      "publicationCount": 2
    }
  }
}
"""#
}
