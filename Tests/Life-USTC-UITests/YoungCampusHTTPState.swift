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
            if let fixture = fixtures["\(request.method) \(path)"] {
                if let image = fixture as? [String: Any], let base64 = image["_fixtureBase64"] as? String,
                   let data = Data(base64Encoded: base64) { return (200, data) }
                return (200, fixture)
            }
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
        "allowedAttachmentTypes": [
          "pdf",
          "docx"
        ],
        "description": "Practice explaining research to a general audience.",
        "location": "East Campus Student Activity Center",
        "startAt": "2035-09-16T09:00:00+08:00",
        "endAt": "2035-09-16T11:00:00+08:00",
        "applyStartAt": "2035-09-10T09:00:00+08:00",
        "applyEndAt": "2035-09-15T18:00:00+08:00",
        "capacity": 30,
        "appliedCount": 0,
        "hours": 2,
        "requiresSignupInfo": true,
        "requiresSignup": true,
        "grades": "Graduate students only",
        "isOnline": true,
        "onlineMeetingInfo": "800-414-186",
        "externalSponsor": "External sponsor fixture",
        "signupScopeCode": "future-scope"
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
    "allowedAttachmentTypes": [
      "pdf",
      "docx"
    ],
    "description": "Practice explaining research to a general audience.",
    "location": "East Campus Student Activity Center",
    "startAt": "2035-09-16T09:00:00+08:00",
    "endAt": "2035-09-16T11:00:00+08:00",
    "applyStartAt": "2035-09-10T09:00:00+08:00",
    "applyEndAt": "2035-09-15T18:00:00+08:00",
    "capacity": 30,
    "appliedCount": 0,
    "hours": 2,
    "requiresSignupInfo": true,
    "requiresSignup": true,
    "grades": "Graduate students only",
    "isOnline": true,
    "onlineMeetingInfo": "800-414-186",
    "externalSponsor": "External sponsor fixture",
    "signupScopeCode": "future-scope"
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
          "allowedAttachmentTypes": [
            "pdf",
            "docx"
          ],
          "description": "Practice explaining research to a general audience.",
          "location": "East Campus Student Activity Center",
          "startAt": "2035-09-16T09:00:00+08:00",
          "endAt": "2035-09-16T11:00:00+08:00",
          "applyStartAt": "2035-09-10T09:00:00+08:00",
          "applyEndAt": "2035-09-15T18:00:00+08:00",
          "capacity": 30,
          "appliedCount": 0,
          "hours": 2,
          "requiresSignupInfo": true,
          "requiresSignup": true,
          "grades": "Graduate students only",
          "isOnline": true,
          "onlineMeetingInfo": "800-414-186",
          "externalSponsor": "External sponsor fixture",
          "signupScopeCode": "future-scope"
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
      "author": "栏目",
      "reporter": "  Campus Newsroom  ",
      "editor": "https://example.org/editor",
      "originalPublisher": "—",
      "publishedAt": "2026-10-22T09:00:00+08:00",
      "updatedAtSource": null,
      "category": "Campus",
      "summary": "Lectures, workshops, and open laboratories across campus.",
      "sourcePageUrl": "https://news.ustc.edu.cn/article",
      "images": [
        {
          "id": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "sourceUrl": "https://news.ustc.edu.cn/laboratory.png",
          "url": "/api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "altText": "Laboratory display",
          "title": "Campus demonstration",
          "caption": "Students share their laboratory work.",
          "sortOrder": 0
        }
      ],
      "bodyMarkdown": "Before the campus demonstration.\n\n![Laboratory display](/api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)\n\nAfter the campus demonstration. Explore **open laboratories**.\n\n| Session | Room |\n| --- | --- |\n| Workshop | East 101 |",
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
    ],
    "renderedBodyHtml": "<p>Before the campus demonstration.</p><figure><img src=\"/api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\" alt=\"Laboratory display\" title=\"Campus demonstration\"><figcaption>Students share their laboratory work.</figcaption></figure><p>After the campus demonstration. Explore <strong>open laboratories</strong>.</p><table><thead><tr><th>Session</th><th>Room</th></tr></thead><tbody><tr><td>Workshop</td><td>East 101</td></tr></tbody></table>"
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
      "author": "栏目",
      "reporter": "  Campus Newsroom  ",
      "editor": "https://example.org/editor",
      "originalPublisher": "—",
      "publishedAt": "2026-10-22T09:00:00+08:00",
      "updatedAtSource": null,
      "category": "Campus",
      "summary": "Lectures, workshops, and open laboratories across campus.",
      "sourcePageUrl": "https://news.ustc.edu.cn/article",
      "images": [
        {
          "id": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "sourceUrl": "https://news.ustc.edu.cn/laboratory.png",
          "url": "/api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "altText": "Laboratory display",
          "title": "Campus demonstration",
          "caption": "Students share their laboratory work.",
          "sortOrder": 0
        }
      ],
      "bodyMarkdown": "Before the campus demonstration.\n\n![Laboratory display](/api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb)\n\nAfter the campus demonstration. Explore **open laboratories**.\n\n| Session | Room |\n| --- | --- |\n| Workshop | East 101 |",
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
    "alsoPublishedIn": [],
    "renderedBodyHtml": "<p>Before the campus demonstration.</p><figure><img src=\"/api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\" alt=\"Laboratory display\" title=\"Campus demonstration\"><figcaption>Students share their laboratory work.</figcaption></figure><p>After the campus demonstration. Explore <strong>open laboratories</strong>.</p><table><thead><tr><th>Session</th><th>Room</th></tr></thead><tbody><tr><td>Workshop</td><td>East 101</td></tr></tbody></table>"
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
  },
  "GET /api/publications/images/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb": {
    "_fixtureContentType": "image/png",
    "_fixtureBase64": "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"
  }
}
"""#
}
