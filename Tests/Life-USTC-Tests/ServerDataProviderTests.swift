import SwiftData
import XCTest
@testable import Life_USTC

final class ServerDataProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    @MainActor
    func testExplicitMeetingDateWinsOverWeekPosition() async throws {
        let context = try makeContext()
        let client = makeClient()
        stubSections([42: section(42, date: "2026-10-23T00:00:00+08:00", weekIndex: 1)])

        try await ServerDataProvider.updateCurriculum(client: client, context: context)

        let lecture = try XCTUnwrap(context.fetch(FetchDescriptor<Lecture>()).first)
        XCTAssertEqual(lecture.startDate, date("2026-10-23T00:15:00Z"))
        XCTAssertEqual(lecture.endDate, date("2026-10-23T01:45:00Z"))
        XCTAssertEqual(lecture.location, "East 2201")
    }

    @MainActor
    func testDateOnlyMeetingWithoutWeekIndexRemainsVisible() async throws {
        let context = try makeContext()
        stubSections([42: section(42, date: "2026-10-23", weekIndex: nil)])

        try await ServerDataProvider.updateCurriculum(client: makeClient(), context: context)

        let lectures = try context.fetch(FetchDescriptor<Lecture>())
        XCTAssertEqual(lectures.count, 1)
        XCTAssertEqual(lectures.first?.startDate, date("2026-10-23T00:15:00Z"))
    }

    @MainActor
    func testUndatedMeetingsUseMondayWeeksAndInclusiveSemesterBounds() async throws {
        let context = try makeContext()
        var detail = section(42, date: "2026-09-01", weekIndex: 1)
        var semester = try XCTUnwrap(detail["semester"] as? [String: Any])
        semester["startDate"] = "2026-09-01T00:00:00+08:00"
        semester["endDate"] = "2026-09-07T00:00:00+08:00"
        detail["semester"] = semester
        let template = try XCTUnwrap((detail["schedules"] as? [[String: Any]])?.first)
        detail["schedules"] = [(1, 1), (1, 2), (1, 7), (2, 1), (2, 2), (0, 3)].enumerated().map { index, position in
            var meeting = template
            meeting["id"] = 300 + index
            meeting["date"] = NSNull()
            meeting["weekIndex"] = position.0
            meeting["weekday"] = position.1
            return meeting
        }
        stubSections([42: detail])

        try await ServerDataProvider.updateCurriculum(client: makeClient(), context: context)

        let starts = try context.fetch(FetchDescriptor<Lecture>()).map(\.startDate).sorted()
        XCTAssertEqual(starts, [
            date("2026-09-01T00:15:00Z"), date("2026-09-06T00:15:00Z"), date("2026-09-07T00:15:00Z"),
        ])
    }

    @MainActor
    func testUndatedMeetingWithoutSemesterEndRetainsLaterTeachingWeek() async throws {
        let context = try makeContext()
        var detail = section(42, date: "2026-09-01", weekIndex: 4)
        var semester = try XCTUnwrap(detail["semester"] as? [String: Any])
        semester["startDate"] = "2026-09-01T00:00:00+08:00"
        semester["endDate"] = NSNull()
        detail["semester"] = semester
        var meeting = try XCTUnwrap((detail["schedules"] as? [[String: Any]])?.first)
        meeting["date"] = NSNull()
        meeting["weekday"] = 3
        detail["schedules"] = [meeting]
        stubSections([42: detail])

        try await ServerDataProvider.updateCurriculum(client: makeClient(), context: context)

        let lectures = try context.fetch(FetchDescriptor<Lecture>())
        XCTAssertEqual(lectures.count, 1)
        XCTAssertEqual(lectures.first?.startDate, date("2026-09-23T00:15:00Z"))
    }

    @MainActor
    func testOfferingsOfOneCourseKeepDistinctIdentityAndSemesters() async throws {
        let context = try makeContext()
        stubSections([
            42: section(42, semesterID: 1, date: "2026-10-23", weekIndex: nil),
            43: section(43, semesterID: 2, date: "2026-10-24", weekIndex: nil),
        ])

        try await ServerDataProvider.updateCurriculum(client: makeClient(), context: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        XCTAssertEqual(Set(courses.map(\.jw_id)), [42, 43])
        XCTAssertEqual(Set(courses.compactMap { $0.semester?.jw_id }), ["101", "102"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Curriculum>()), 1)
    }

    @MainActor
    func testSuccessfulEmptySubscriptionsRemoveOldLearningSnapshot() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        stubSections([:])
        let client = makeClient()

        try await ServerDataProvider.refreshLearningData(client: client, context: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Semester>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exam>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Curriculum>()), 0)
    }

    @MainActor
    func testPartialDetailFailurePreservesLastCurriculumAndExamSnapshot() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        stubSections([
            42: section(42, date: "2026-10-23", weekIndex: 1),
            43: section(43, date: "2026-10-24", weekIndex: 1),
        ], failingSection: 43)
        let client = makeClient()

        do {
            try await ServerDataProvider.refreshLearningData(client: client, context: context)
            XCTFail("An incomplete snapshot must fail without committing its successful prefix")
        } catch {}

        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exam>()).map(\.courseName), ["Cached exam"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 1)
    }

    @MainActor
    func testCombinedRefreshFetchesOnceAndMakesExamAndCourseVisibleToReaders() async throws {
        let reader = try makeContext()
        try seedLearningSnapshot(reader)
        let writer = ModelContext(reader.container)
        var detail = section(42, date: "2026-10-23", weekIndex: nil)
        detail["exams"] = [["id": 501, "examDate": "2026-12-23", "startTime": 900, "endTime": 1100]]
        stubSections([42: detail])

        try await ServerDataProvider.refreshLearningData(client: makeClient(), context: writer)

        XCTAssertEqual(try reader.fetch(FetchDescriptor<Course>()).map(\.jw_id), [42])
        let exam = try XCTUnwrap(reader.fetch(FetchDescriptor<Exam>()).first)
        XCTAssertEqual(exam.courseName, "Calculus")
        XCTAssertEqual(exam.startDate, date("2026-12-23T01:00:00Z"))
        XCTAssertEqual(MockURLProtocol.capturedRequests.map { $0.url!.path }, [
            "/api/workspace/subscriptions/current", "/api/catalog/sections/42",
        ])
    }

    @MainActor
    func testRepeatedNonemptySnapshotReplacesMatchingKeysAndRemovesOldRelationships() async throws {
        let context = try makeContext()
        let client = makeClient()
        var first = section(42, date: "2026-10-23", weekIndex: nil)
        var extraMeeting = try XCTUnwrap((first["schedules"] as? [[String: Any]])?.first)
        extraMeeting["id"] = 999
        extraMeeting["date"] = "2026-10-24"
        first["schedules"] = (first["schedules"] as? [[String: Any]] ?? []) + [extraMeeting]
        first["exams"] = [
            ["id": 501, "examDate": "2026-12-23", "startTime": 900, "endTime": 1100],
            ["id": 502, "examDate": "2026-12-24", "startTime": 900, "endTime": 1100],
        ]
        var removed = section(43, date: "2026-10-25", weekIndex: nil)
        removed["exams"] = [["id": 503, "examDate": "2026-12-25", "startTime": 900, "endTime": 1100]]
        stubSections([42: first, 43: removed])
        try await ServerDataProvider.refreshLearningData(client: client, context: ModelContext(context.container))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exam>()), 3)

        var replacement = section(42, date: "2026-10-26", weekIndex: nil)
        replacement["exams"] = [["id": 501, "examDate": "2026-12-26", "startTime": 1300, "endTime": 1500]]
        stubSections([42: replacement])
        try await ServerDataProvider.refreshLearningData(client: client, context: ModelContext(context.container))

        let reader = ModelContext(context.container)
        let curriculum = try XCTUnwrap(reader.fetch(FetchDescriptor<Curriculum>()).first)
        XCTAssertEqual(try reader.fetchCount(FetchDescriptor<Curriculum>()), 1)
        XCTAssertEqual(try reader.fetchCount(FetchDescriptor<Semester>()), 1)
        XCTAssertEqual(try reader.fetchCount(FetchDescriptor<Course>()), 1)
        XCTAssertEqual(try reader.fetchCount(FetchDescriptor<Lecture>()), 1)
        XCTAssertEqual(try reader.fetchCount(FetchDescriptor<Exam>()), 1)
        XCTAssertEqual(curriculum.semesters.map(\.jw_id), ["101"])
        let semester = try XCTUnwrap(curriculum.semesters.first)
        XCTAssertEqual(semester.courses.map(\.jw_id), [42])
        let course = try XCTUnwrap(semester.courses.first)
        XCTAssertEqual(course.lectures.count, 1)
        XCTAssertEqual(course.lectures.first?.course?.jw_id, 42)
        XCTAssertEqual(course.lectures.first?.startDate, date("2026-10-26T00:15:00Z"))
        XCTAssertEqual(try reader.fetch(FetchDescriptor<Exam>()).first?.startDate, date("2026-12-26T05:00:00Z"))
    }

    @MainActor
    func testAnonymousColdStartClearsOnlyPreviousLearningSnapshot() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        try seedIndependentData(context)
        let client = makeClient()
        client.clearTokens()
        let account = ServerAccountStore(client: client, learningContext: context, isPresentingDemo: { false })

        await account.loadUser()

        try assertNoLearningSnapshot(context)
        try assertIndependentDataRemains(context)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        XCTAssertNil(account.user)
    }

    @MainActor
    func testSignedInColdStartPreservesOfflineLearningSnapshot() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        let account = ServerAccountStore(client: makeClient(), learningContext: context, isPresentingDemo: { false })
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
             Data(#"{"error":"Offline fixture"}"#.utf8))
        }

        await account.loadUser()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exam>()).map(\.courseName), ["Cached exam"])
        XCTAssertEqual(account.error, "Offline fixture")
    }

    @MainActor
    func testTemporaryTokenRefreshFailurePreservesLearningSnapshotAndCanRetry() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        let client = makeClient()
        client.refreshToken = "valid-refresh"
        let revision = client.sessionRevision
        let account = ServerAccountStore(client: client, learningContext: context, isPresentingDemo: { false })
        MockURLProtocol.requestHandler = { request in
            let status = request.url?.path.hasSuffix("/token") == true ? 503 : 401
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"error":"server_error"}"#.utf8))
        }

        await account.loadUser()

        XCTAssertTrue(account.isAuthenticated)
        XCTAssertEqual(client.accessToken, "fixture-access-token")
        XCTAssertEqual(client.refreshToken, "valid-refresh")
        XCTAssertEqual(client.sessionRevision, revision)
        XCTAssertNotNil(account.error)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exam>()).map(\.courseName), ["Cached exam"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 1)
        XCTAssertEqual(MockURLProtocol.capturedRequests.map { $0.url!.path }, [
            "/api/account/profile", "/api/auth/oauth2/token",
        ])

        MockURLProtocol.requestHandler = { request in
            if request.url?.path.hasSuffix("/token") == true {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data(#"{"access_token":"renewed-access","refresh_token":"renewed-refresh","token_type":"Bearer"}"#.utf8))
            }
            let status = request.value(forHTTPHeaderField: "Authorization") == "Bearer renewed-access" ? 200 : 401
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"fixture-student","name":"Student"}"#.utf8))
        }

        await account.loadUser()

        XCTAssertEqual(account.user?.id, "fixture-student")
        XCTAssertNil(account.error)
        XCTAssertEqual(client.accessToken, "renewed-access")
        XCTAssertEqual(client.refreshToken, "renewed-refresh")
        XCTAssertEqual(client.sessionRevision, revision)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exam>()).map(\.courseName), ["Cached exam"])
    }

    @MainActor
    func testInvalidRefreshGrantClearsSessionAndOnlyLearningSnapshot() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        try seedIndependentData(context)
        let client = makeClient()
        client.refreshToken = "revoked-refresh"
        let revision = client.sessionRevision
        let account = ServerAccountStore(client: client, learningContext: context, isPresentingDemo: { false })
        MockURLProtocol.requestHandler = { request in
            let status = request.url?.path.hasSuffix("/token") == true ? 400 : 401
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"error":"invalid_grant","error_description":"The refresh token no longer has an active user grant."}"#.utf8))
        }

        await account.loadUser()

        XCTAssertFalse(account.isAuthenticated)
        XCTAssertTrue(client.accessToken.isEmpty)
        XCTAssertTrue(client.refreshToken.isEmpty)
        XCTAssertNotEqual(client.sessionRevision, revision)
        XCTAssertNil(account.user)
        try assertNoLearningSnapshot(context)
        try assertIndependentDataRemains(context)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    @MainActor
    func testDemoModeSkipsLiveRefreshAndResumesAfterLeavingDemo() async throws {
        let production = try makeContext()
        let demo = try makeContext()
        try seedLearningSnapshot(production)
        try seedLearningSnapshot(demo)
        var showingDemo = true
        let account = ServerAccountStore(client: makeClient(), learningContext: production,
                                         isPresentingDemo: { showingDemo })
        stubSections([42: section(42, date: "2026-10-23", weekIndex: nil)])

        await account.refreshLearningData()

        XCTAssertEqual(try production.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try demo.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)

        showingDemo = false
        await account.refreshLearningData()

        XCTAssertEqual(try production.fetch(FetchDescriptor<Course>()).map(\.jw_id), [42])
        XCTAssertEqual(try demo.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
    }

    @MainActor
    func testLogoutWhileShowingDemoClearsProductionCacheAndPreservesOtherSources() throws {
        let production = try makeContext()
        let demo = try makeContext()
        try seedLearningSnapshot(production)
        try seedIndependentData(production)
        try seedLearningSnapshot(demo)
        let account = ServerAccountStore(client: makeClient(), learningContext: production, isPresentingDemo: { true })

        account.logout()

        try assertNoLearningSnapshot(production)
        try assertIndependentDataRemains(production)
        XCTAssertEqual(try demo.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try demo.fetch(FetchDescriptor<Exam>()).map(\.courseName), ["Cached exam"])
        XCTAssertFalse(account.isAuthenticated)
    }

    @MainActor
    func testBackendChangeWhileShowingDemoClearsProductionCache() throws {
        let production = try makeContext()
        let demo = try makeContext()
        try seedLearningSnapshot(production)
        try seedIndependentData(production)
        try seedLearningSnapshot(demo)
        let client = makeClient()
        let account = ServerAccountStore(client: client, learningContext: production, isPresentingDemo: { true })
        let previousBackend = UserDefaults.standard.object(forKey: "serverBaseURL")
        defer { UserDefaults.standard.set(previousBackend, forKey: "serverBaseURL") }

        client.reconfigure(baseURL: URL(string: "https://another.example.test")!)
        account.onBackendChanged()

        try assertNoLearningSnapshot(production)
        try assertIndependentDataRemains(production)
        XCTAssertEqual(try demo.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
        XCTAssertEqual(try demo.fetch(FetchDescriptor<Exam>()).map(\.courseName), ["Cached exam"])
    }

    @MainActor
    func testChangedSessionDiscardsInFlightLearningResponse() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        let client = makeClient()
        stubSections([42: section(42, date: "2026-10-23", weekIndex: nil)], beforeDetailResponse: {
            client.clearTokens()
        })

        do {
            try await ServerDataProvider.updateCurriculum(client: client, context: context)
            XCTFail("A former session must never commit its response")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected cancellation after session change, got \(error)")
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
    }

    @MainActor
    func testCancelledRefreshDoesNotChangeSnapshot() async throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        stubSections([42: section(42, date: "2026-10-23", weekIndex: nil)])
        let client = makeClient()
        let task = Task { @MainActor in
            try await ServerDataProvider.updateCurriculum(client: client, context: context)
        }
        task.cancel()
        do {
            try await task.value
            XCTFail("Cancelled refresh must not commit")
        } catch {}
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Cached course"])
    }

    @MainActor
    func testClearLearningDataPreservesGradesFeedsAndBlackboard() throws {
        let context = try makeContext()
        try seedLearningSnapshot(context)
        try seedIndependentData(context)

        try ServerDataProvider.clearCachedLearningData(context: context)

        try assertNoLearningSnapshot(context)
        try assertIndependentDataRemains(context)
    }

    @MainActor
    private func assertNoLearningSnapshot(_ context: ModelContext, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Semester>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Curriculum>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exam>()), 0, file: file, line: line)
    }

    @MainActor
    private func assertIndependentDataRemains(_ context: ModelContext, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Homework>()), 1, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScoreEntry>()), 1, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScoreSheet>()), 1, file: file, line: line)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ScoreSheet>()).first?.entries.first?.score, "95", file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Feed>()), 1, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FeedSource>()), 1, file: file, line: line)
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Curriculum.self, Semester.self, Course.self, Lecture.self, Exam.self,
                             Homework.self, ScoreSheet.self, ScoreEntry.self, FeedSource.self, Feed.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
        context.autosaveEnabled = false
        return context
    }

    private func makeClient() -> ServerClient {
        let tokenStore = MockTokenStore()
        tokenStore.accessToken = "fixture-access-token"
        return ServerClient(configuration: .init(baseURL: URL(string: "https://example.test")!,
                                                session: MockURLProtocol.mockSession(), tokenStore: tokenStore))
    }

    @MainActor
    private func seedLearningSnapshot(_ context: ModelContext) throws {
        let curriculum = Curriculum()
        context.insert(curriculum)
        let semester = Semester(jw_id: "old-term", name: "Cached term", startDate: date("2026-09-01T00:00:00Z"),
                                endDate: date("2027-01-31T00:00:00Z"))
        context.insert(semester)
        semester.curriculum = curriculum
        let course = Course(jw_id: 999, name: "Cached course", courseCode: "OLD", lessonCode: "OLD.01", teacherName: "Teacher")
        context.insert(course)
        course.semester = semester
        let lecture = Lecture(startDate: date("2026-10-23T00:00:00Z"), endDate: date("2026-10-23T01:00:00Z"),
                              name: "Cached lecture", location: "Old room", teacherName: "Teacher", periods: 1)
        context.insert(lecture)
        lecture.course = course
        context.insert(Exam(lessonCode: "OLD.01", courseName: "Cached exam", typeName: "Final",
                            startDate: date("2026-12-23T00:00:00Z"), endDate: date("2026-12-23T01:00:00Z"),
                            classRoomName: "Old room", classRoomBuildingName: "", classRoomDistrict: "", description: ""))
        try context.save()
    }

    @MainActor
    private func seedIndependentData(_ context: ModelContext) throws {
        context.insert(Homework(title: "Blackboard", courseName: "Private course", dueDate: date("2026-11-01T00:00:00Z")))
        let sheet = ScoreSheet(gpa: 4)
        context.insert(sheet)
        let grade = ScoreEntry(courseName: "Grade", courseCode: "G1", lessonCode: "G1.1", semesterID: "1",
                               semesterName: "Term", credit: 4, score: "95")
        context.insert(grade)
        grade.scoreSheet = sheet
        let source = FeedSource(url: URL(string: "https://example.test/feed")!, name: "News")
        context.insert(source)
        let feed = Feed(title: "Saved article", keywords: [], datePosted: date("2026-10-23T00:00:00Z"),
                        url: URL(string: "https://example.test/article")!)
        context.insert(feed)
        feed.source = source
        try context.save()
    }

    private func stubSections(_ sections: [Int: [String: Any]], failingSection: Int? = nil,
                              beforeDetailResponse: (() -> Void)? = nil) {
        MockURLProtocol.requestHandler = { request in
            let object: Any
            var status = 200
            if request.url?.path == "/api/workspace/subscriptions/current" {
                object = ["subscription": ["userId": "fixture-student", "sections": sections.keys.sorted().map {
                    ["id": $0 + 100, "jwId": $0, "code": "MATH.\($0)", "kind": "regular"] as [String: Any]
                }]]
            } else if let key = Int(request.url?.lastPathComponent ?? ""), let section = sections[key] {
                beforeDetailResponse?()
                if key == failingSection {
                    status = 503
                    object = ["error": "Detail temporarily unavailable"]
                } else {
                    object = section
                }
            } else {
                status = 404
                object = ["error": "Unexpected fixture request"]
            }
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                    headerFields: ["Content-Type": "application/json"])!,
                    try JSONSerialization.data(withJSONObject: object))
        }
    }

    private func section(_ jwID: Int, semesterID: Int = 1, date: String, weekIndex: Int?) -> [String: Any] {
        [
            "id": jwID + 100, "jwId": jwID, "code": "MATH.\(jwID)", "credits": 4,
            "course": ["id": 11, "jwId": 1001, "code": "MATH", "nameCn": "Calculus"],
            "semester": ["id": semesterID, "jwId": semesterID + 100, "code": "TERM-\(semesterID)",
                         "nameCn": "Term \(semesterID)", "startDate": "2026-09-07T00:00:00+08:00",
                         "endDate": "2027-01-31T00:00:00+08:00"],
            "teachers": [], "exams": [],
            "schedules": [["id": jwID + 200, "date": date, "weekIndex": weekIndex as Any? ?? NSNull(),
                           "weekday": 1, "startTime": "08:15", "endTime": "09:45", "periods": 1.5,
                           "customPlace": "East 2201"]],
        ]
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
