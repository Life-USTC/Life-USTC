import XCTest
@testable import Life_USTC

final class ServerCommunityTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2035-09-15T10:30:25+08:00"

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "community-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://community.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    func testDescriptionReadsUseEachPublicTargetIdentifier() async throws {
        let targets: [(ServerDescriptionTarget, String, String, String)] = [
            (.course(jwId: 101), "course", "courseJwId", "101"),
            (.section(jwId: 202), "section", "sectionJwId", "202"),
            (.teacher(id: 303), "teacher", "teacherId", "303"),
            (.homework(id: "homework + & 中文"), "homework", "homeworkId", "homework + & 中文")
        ]
        MockURLProtocol.stubJSON(description())
        for (target, type, key, value) in targets {
            _ = try await client.fetchDescription(for: target)
            let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/community/descriptions")
            XCTAssertEqual(query(request), ["targetType": type, key: value])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer community-owner")
        }
    }

    func testDescriptionReadRetainsServerHTMLLatestTwentyEditsAndSuspendedViewer() async throws {
        var payload = description(historyCount: 20)
        payload["viewer"] = viewer(suspended: true)
        MockURLProtocol.stubJSON(payload)
        let result = try await client.fetchDescription(for: .section(jwId: 202))
        XCTAssertEqual(result.description.content, "**Shared** supplement")
        XCTAssertEqual(result.description.renderedHtml, "<p><strong>Shared</strong> supplement</p>")
        XCTAssertEqual(result.description.lastEditedBy?.username, "editor")
        XCTAssertEqual(result.description.lastEditedAt, ISO8601DateFormatter().date(from: timestamp))
        XCTAssertEqual(result.history.map(\.id), (0..<20).map { "edit-\($0)" })
        XCTAssertNil(result.history.last?.previousContent)
        XCTAssertEqual(result.history.first?.nextContent, "Revision 0")
        XCTAssertEqual(result.history.first?.editor?.id, "editor-id")
        XCTAssertTrue(result.viewer.isAuthenticated)
        XCTAssertTrue(result.viewer.isSuspended)
        XCTAssertEqual(result.viewer.suspensionReason, "Read only")
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1,
                       "Description history is the server's latest-20 window, not a paginated endpoint")
    }

    func testUnwrittenDescriptionKeepsNullIdentityAndAnonymousPermissions() async throws {
        client.clearTokens()
        MockURLProtocol.stubJSON([
            "description": ["id": NSNull(), "content": "", "renderedHtml": "",
                            "updatedAt": NSNull(), "lastEditedAt": NSNull(), "lastEditedBy": NSNull()],
            "history": [], "viewer": viewer(authenticated: false)
        ])
        let result = try await client.fetchDescription(for: .teacher(id: 303))
        XCTAssertNil(result.description.id)
        XCTAssertNil(result.description.updatedAt)
        XCTAssertNil(result.description.lastEditedBy)
        XCTAssertTrue(result.history.isEmpty)
        XCTAssertFalse(result.viewer.isAuthenticated)
        XCTAssertNil(result.viewer.userId)
        XCTAssertNil(MockURLProtocol.capturedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func testDescriptionUpsertUsesPublicIdentifiersAndPreservesMarkdown() async throws {
        let content = "# Heading\n\n[Section](ustc://section/202)\n中文 & notes"
        let targets: [(ServerDescriptionTarget, String, Any)] = [
            (.course(jwId: 101), "courseJwId", 101),
            (.section(jwId: 202), "sectionJwId", 202),
            (.teacher(id: 303), "teacherId", 303),
            (.homework(id: "opaque-homework"), "homeworkId", "opaque-homework")
        ]
        MockURLProtocol.stubJSON(["id": "description", "updated": true])
        for (target, key, value) in targets {
            let result = try await client.upsertDescription(for: target, content: content)
            XCTAssertEqual(result.id, "description")
            XCTAssertTrue(result.updated)
            let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/community/descriptions")
            let body = try requestBody(request)
            XCTAssertEqual(Set(body.keys), ["targetType", key, "content"])
            XCTAssertEqual(body["targetType"] as? String, target.targetType)
            XCTAssertEqual(body["content"] as? String, content)
            if let number = value as? Int { XCTAssertEqual(body[key] as? Int, number) }
            else { XCTAssertEqual(body[key] as? String, value as? String) }
        }
    }

    func testUnchangedDescriptionStillRefreshesItsCanonicalRead() async throws {
        let community = expectation(description: "Unchanged retry refreshes community")
        community.assertForOverFulfill = true
        let workspace = expectation(description: "Course supplement does not refresh private workspace")
        workspace.isInverted = true
        let communityObserver = NotificationCenter.default.addObserver(forName: .serverCommunityDidChange, object: nil, queue: .main) { _ in community.fulfill() }
        let workspaceObserver = NotificationCenter.default.addObserver(forName: .serverWorkspaceDidChange, object: nil, queue: .main) { _ in workspace.fulfill() }
        defer {
            NotificationCenter.default.removeObserver(communityObserver)
            NotificationCenter.default.removeObserver(workspaceObserver)
        }
        MockURLProtocol.stubJSON(["id": "description", "updated": false])
        let result = try await client.upsertDescription(for: .course(jwId: 101), content: "Already saved")
        XCTAssertFalse(result.updated)
        await fulfillment(of: [community, workspace], timeout: 0.05)
    }

    func testPublicProfilePreservesNullableIdentityAndShanghaiContributionDays() async throws {
        client.clearTokens()
        MockURLProtocol.stubJSON([
            "user": ["id": "stable-user", "username": NSNull(), "name": "Display name",
                     "image": NSNull(), "createdAt": timestamp,
                     "_count": ["comments": 4, "uploads": 2, "homeworksCreated": 1]],
            "weeks": [[ ["date": "2035-09-09", "count": 0],
                         ["date": "2035-09-10", "count": 3] ]],
            "totalContributions": 3
        ])
        let profile = try await client.fetchPublicUserProfile(identifier: "stable-user")
        XCTAssertEqual(profile.user.id, "stable-user")
        XCTAssertNil(profile.user.username)
        XCTAssertEqual(profile.user.name, "Display name")
        XCTAssertEqual(profile.user.counts.comments, 4)
        XCTAssertEqual(profile.user.counts.uploads, 2)
        XCTAssertEqual(profile.user.counts.homeworksCreated, 1)
        XCTAssertEqual(profile.weeks.first?.map(\.date), ["2035-09-09", "2035-09-10"])
        XCTAssertEqual(profile.weeks.first?.map(\.count), [0, 3])
        XCTAssertEqual(profile.totalContributions, 3)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/community/users/stable-user")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testFocusedCommentPreservesMaskedAuthorPermissionsAndNavigationContext() async throws {
        var anonymous = comment("focus")
        anonymous["isAnonymous"] = true
        anonymous["authorHidden"] = true
        anonymous["author"] = NSNull()
        anonymous["canEdit"] = false
        anonymous["canDelete"] = false
        anonymous["canReply"] = true
        anonymous["reactions"] = [["type": "like", "count": 2, "viewerHasReacted": true]]
        anonymous["attachments"] = [["id": "attachment", "uploadId": "upload",
                                      "filename": "notes.pdf", "url": "/api/community/uploads/upload/download",
                                      "contentType": "application/pdf", "size": 120]]
        var root = comment("root")
        root["replies"] = [anonymous]
        root["repliesNextCursor"] = "next-cursor"
        MockURLProtocol.stubJSON([
            "thread": [root], "focusId": "focus", "hiddenCount": 1, "viewer": viewer(),
            "target": ["sectionTeacherId": 6, "sectionTeacherSectionId": 7,
                       "sectionTeacherSectionJwId": 202, "sectionTeacherTeacherId": 303,
                       "sectionTeacherSectionCode": "MATH101.01", "sectionTeacherTeacherName": "Teacher",
                       "sectionTeacherCourseJwId": 101, "sectionTeacherCourseName": "Math"]
        ])
        let response = try await client.fetchCommentThread(id: "focus")
        XCTAssertEqual(response.focusId, "focus")
        XCTAssertEqual(response.hiddenCount, 1)
        XCTAssertEqual(response.thread.first?.id, "root")
        XCTAssertEqual(response.thread.first?.repliesNextCursor, "next-cursor")
        let focused = try XCTUnwrap(response.thread.first?.replies?.first)
        XCTAssertTrue(focused.isAnonymous)
        XCTAssertNil(focused.author)
        XCTAssertEqual(focused.canEdit, false)
        XCTAssertEqual(focused.canReply, true)
        XCTAssertEqual(focused.reactions.first?.viewerHasReacted, true)
        XCTAssertEqual(focused.attachments?.first?.filename, "notes.pdf")
        XCTAssertEqual(response.target.sectionTeacherSectionJwId, 202)
        XCTAssertEqual(response.target.sectionTeacherTeacherId, 303)
        XCTAssertNil(response.target.youngId)
        XCTAssertEqual(response.viewer.userId, "owner")
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/api/community/comments/focus")
    }

    func testSharedHomeworkCreateReturnsCanonicalItemAndUsesSectionJWID() async throws {
        MockURLProtocol.stubJSON(["id": "created", "homework": homework("created")], statusCode: 201)
        let result = try await client.createHomework(CreateHomeworkRequest(
            sectionJwId: 202, title: "Shared assignment", description: "Notes",
            publishedAt: timestamp, submissionStartAt: nil, submissionDueAt: timestamp,
            isMajor: true, requiresTeam: true
        ))
        XCTAssertEqual(result.id, "created")
        XCTAssertEqual(result.section?.jwId, 202)
        XCTAssertEqual(result.updatedBy?.username, "editor")
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/community/section-homeworks")
        let body = try requestBody(request)
        XCTAssertEqual(body["sectionJwId"] as? Int, 202)
        XCTAssertNil(body["sectionId"])
        XCTAssertEqual(body["title"] as? String, "Shared assignment")
        XCTAssertEqual(body["description"] as? String, "Notes")
        XCTAssertEqual(body["submissionDueAt"] as? String, timestamp)
        XCTAssertEqual(body["isMajor"] as? Bool, true)
        XCTAssertEqual(body["requiresTeam"] as? Bool, true)
    }

    func testHomeworkPatchDistinguishesOmittedAndExplicitlyClearedFields() async throws {
        MockURLProtocol.stubJSON(["success": true, "homework": homework("edited")])
        _ = try await client.updateHomework(id: "edited", request: UpdateHomeworkRequest(title: "New title"))
        var request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/community/section-homeworks/edited")
        var body = try requestBody(request)
        XCTAssertEqual(Set(body.keys), ["title"])

        _ = try await client.updateHomework(id: "edited", request: UpdateHomeworkRequest(
            description: .null, publishedAt: .null, submissionStartAt: .null, submissionDueAt: .null,
            isMajor: false, requiresTeam: false
        ))
        body = try requestBody(XCTUnwrap(MockURLProtocol.capturedRequests.last))
        for key in ["description", "publishedAt", "submissionStartAt", "submissionDueAt"] {
            XCTAssertTrue(body[key] is NSNull, "\(key) must explicitly clear persisted data")
        }
        XCTAssertEqual(body["isMajor"] as? Bool, false)
        XCTAssertEqual(body["requiresTeam"] as? Bool, false)
        XCTAssertNil(body["title"])

        _ = try await client.updateHomework(id: "edited", request: UpdateHomeworkRequest(
            description: .value("New details"), publishedAt: .value(timestamp),
            submissionStartAt: .value(timestamp), submissionDueAt: .value(timestamp)
        ))
        request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        body = try requestBody(request)
        XCTAssertEqual(body["description"] as? String, "New details")
        XCTAssertEqual(body["publishedAt"] as? String, timestamp)
        XCTAssertEqual(body["submissionStartAt"] as? String, timestamp)
        XCTAssertEqual(body["submissionDueAt"] as? String, timestamp)
    }

    func testHomeworkDetailAndSectionAuditRetainLatestFiftyEntries() async throws {
        let entries = (0..<50).map { audit("audit-\($0)", action: $0 == 0 ? "deleted" : "updated") }
        MockURLProtocol.stubJSON(["homework": homework("history"), "auditLogs": entries])
        let detail = try await client.fetchHomeworkDetail(id: "history")
        XCTAssertEqual(detail.homework.id, "history")
        XCTAssertEqual(detail.auditLogs?.count, 50)
        XCTAssertEqual(detail.auditLogs?.first?.action, .deleted)
        XCTAssertEqual(detail.auditLogs?.first?.titleSnapshot, "Previous title")
        XCTAssertEqual(detail.auditLogs?.last?.id, "audit-49")

        MockURLProtocol.stubJSON(["auditLogs": entries])
        let history = try await client.fetchHomeworkAudit(sectionJwId: 202)
        XCTAssertEqual(history.map(\.id), entries.compactMap { $0["id"] as? String })
        XCTAssertEqual(history.first?.actor?.username, "editor")
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.last)
        XCTAssertEqual(request.url?.path, "/api/community/section-homeworks/audit")
        XCTAssertEqual(query(request), ["sectionJwId": "202"])
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testHomeworkChangesNotifyCommunityAndWorkspaceOnceAfterSuccess() async throws {
        for operation in ["create", "update", "delete", "description"] {
            let community = expectation(description: "One community notification for \(operation)")
            let workspace = expectation(description: "One workspace notification for \(operation)")
            community.assertForOverFulfill = true
            workspace.assertForOverFulfill = true
            let first = NotificationCenter.default.addObserver(forName: .serverCommunityDidChange, object: nil, queue: .main) { _ in community.fulfill() }
            let second = NotificationCenter.default.addObserver(forName: .serverWorkspaceDidChange, object: nil, queue: .main) { _ in workspace.fulfill() }
            defer {
                NotificationCenter.default.removeObserver(first)
                NotificationCenter.default.removeObserver(second)
            }
            switch operation {
            case "create": MockURLProtocol.stubJSON(["id": "created", "homework": homework("created")], statusCode: 201)
            case "update": MockURLProtocol.stubJSON(["success": true, "homework": homework("updated")])
            case "delete": MockURLProtocol.stubJSON(["success": true])
            default: MockURLProtocol.stubJSON(["id": "description", "updated": true])
            }
            try await performMutation(operation)
            NotificationCenter.default.removeObserver(first)
            NotificationCenter.default.removeObserver(second)
            await fulfillment(of: [community, workspace], timeout: 1)
        }
        XCTAssertEqual(MockURLProtocol.capturedRequests.first { $0.httpMethod == "DELETE" }?.url?.path,
                       "/api/community/section-homeworks/homework")
    }

    func testRejectedCommunityWritesNeverPostSuccessOrRetryAutomatically() async throws {
        let changed = expectation(description: "No success after rejected community writes")
        changed.isInverted = true
        let first = NotificationCenter.default.addObserver(forName: .serverCommunityDidChange, object: nil, queue: .main) { _ in changed.fulfill() }
        let second = NotificationCenter.default.addObserver(forName: .serverWorkspaceDidChange, object: nil, queue: .main) { _ in changed.fulfill() }
        defer {
            NotificationCenter.default.removeObserver(first)
            NotificationCenter.default.removeObserver(second)
        }
        MockURLProtocol.stubJSON(["error": "Suspended"], statusCode: 403)
        for operation in ["create", "update", "delete", "description"] {
            do {
                try await performMutation(operation)
                XCTFail("Rejected \(operation) must report failure")
            } catch ServerError.forbidden { }
        }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 4)
        await fulfillment(of: [changed], timeout: 0.05)
    }

    func testAccountReplacementDuringUpsertRejectsFormerOwnersResultAndNotifications() async throws {
        let changed = expectation(description: "No former-owner success notification")
        changed.isInverted = true
        let observer = NotificationCenter.default.addObserver(forName: .serverCommunityDidChange, object: nil, queue: .main) { _ in changed.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }
        let client = client!
        let revision = client.sessionRevision
        MockURLProtocol.requestHandler = { request in
            try client.acceptAuthorization(OAuthTokenResponse(
                accessToken: "next-owner", tokenType: "Bearer", expiresIn: nil,
                refreshToken: nil, scope: nil
            ), expectedRevision: revision)
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"former-description","updated":true}"#.utf8))
        }
        do {
            _ = try await client.upsertDescription(for: .homework(id: "homework"), content: "Former owner's edit")
            XCTFail("An earlier session's save response must not report success")
        } catch is CancellationError { }
        await fulfillment(of: [changed], timeout: 0.05)
    }

    func testStaleEditorRevisionCannotSendAnyCommunityWriteUnderReplacementAccount() async throws {
        let revision = client.sessionRevision
        try client.acceptAuthorization(OAuthTokenResponse(
            accessToken: "next-owner", tokenType: "Bearer", expiresIn: nil,
            refreshToken: nil, scope: nil
        ), expectedRevision: revision)
        MockURLProtocol.stubJSON(["success": true])
        for operation in ["create", "update", "delete", "description"] {
            do {
                try await performMutation(operation, expectedRevision: revision)
                XCTFail("A stale \(operation) must be cancelled before starting a request")
            } catch is CancellationError { }
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        XCTAssertEqual(client.accessToken, "next-owner")
    }

    func testPublicAndFocusedReadErrorsRetainTheirDomainMeaning() async throws {
        MockURLProtocol.stubJSON(["error": "Not found"], statusCode: 404)
        do {
            _ = try await client.fetchDescription(for: .course(jwId: 404))
            XCTFail("A missing target is not an empty description")
        } catch ServerError.notFound { }
        do {
            _ = try await client.fetchPublicUserProfile(identifier: "missing")
            XCTFail("A missing profile is not an anonymous profile")
        } catch ServerError.notFound { }
        MockURLProtocol.stubJSON(["error": "Private comment"], statusCode: 403)
        do {
            _ = try await client.fetchCommentThread(id: "private")
            XCTFail("An inaccessible thread must not become an empty public thread")
        } catch ServerError.forbidden { }
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 3)
    }

    private func performMutation(_ operation: String, expectedRevision: UUID? = nil) async throws {
        switch operation {
        case "create":
            _ = try await client.createHomework(CreateHomeworkRequest(
                sectionJwId: 202, title: "Assignment", description: nil, publishedAt: nil,
                submissionStartAt: nil, submissionDueAt: nil, isMajor: nil, requiresTeam: nil
            ), expectedRevision: expectedRevision)
        case "update":
            _ = try await client.updateHomework(
                id: "homework", request: UpdateHomeworkRequest(title: "Edited"), expectedRevision: expectedRevision
            )
        case "delete": try await client.deleteHomework(id: "homework", expectedRevision: expectedRevision)
        default:
            _ = try await client.upsertDescription(
                for: .homework(id: "homework"), content: "Details", expectedRevision: expectedRevision
            )
        }
    }

    private func viewer(authenticated: Bool = true, suspended: Bool = false) -> [String: Any] {
        ["userId": authenticated ? "owner" as Any : NSNull(), "name": NSNull(), "image": NSNull(),
         "isAdmin": false, "isAuthenticated": authenticated, "isSuspended": suspended,
         "suspensionReason": suspended ? "Read only" as Any : NSNull(), "suspensionExpiresAt": NSNull()]
    }

    private func actor() -> [String: Any] {
        ["id": "editor-id", "name": "Editor", "username": "editor", "image": NSNull()]
    }

    private func description(historyCount: Int = 0) -> [String: Any] {
        ["description": ["id": "description", "content": "**Shared** supplement",
                         "renderedHtml": "<p><strong>Shared</strong> supplement</p>", "updatedAt": timestamp,
                         "lastEditedAt": timestamp, "lastEditedBy": actor()],
         "history": (0..<historyCount).map { index in
             ["id": "edit-\(index)", "createdAt": timestamp,
              "previousContent": index == historyCount - 1 ? NSNull() : "Previous \(index)" as Any,
              "nextContent": "Revision \(index)", "editor": actor()] as [String: Any]
         }, "viewer": viewer()]
    }

    private func comment(_ id: String) -> [String: Any] {
        ["id": id, "body": "Comment \(id)", "renderedBody": "<p>Comment</p>",
         "visibility": "public", "status": "active", "isAnonymous": false,
         "createdAt": timestamp, "updatedAt": timestamp, "reactions": [], "replies": []]
    }

    private func homework(_ id: String) -> [String: Any] {
        ["id": id, "sectionId": 7, "title": "Canonical \(id)", "isMajor": true,
         "requiresTeam": true, "completionRequired": true, "createdAt": timestamp, "updatedAt": timestamp,
         "description": ["id": "description", "content": "Saved details"], "updatedBy": actor(),
         "section": ["id": 7, "jwId": 202, "code": "MATH101.01", "courseId": 3,
                     "course": ["id": 3, "jwId": 101, "code": "MATH101", "nameCn": "数学"]]]
    }

    private func audit(_ id: String, action: String) -> [String: Any] {
        ["id": id, "action": action, "titleSnapshot": "Previous title", "createdAt": timestamp,
         "sectionId": 7, "homeworkId": "homework", "actorId": "editor-id", "actor": actor()]
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
