import XCTest
@testable import Life_USTC

final class WorkspaceExamsModelTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        let tokens = MockTokenStore()
        tokens.accessToken = "exam-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://exams.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testSemesterFilterKeepsUnknownDatesAndHistoryWithStableDetailIDs() async {
        let model = ServerWorkspaceExamsModel(client: client)
        MockURLProtocol.stubJSON(page([
            exam(1, semesterID: 7, startDate: "2034-09-01", examDate: "2035-01-10"),
            exam(2, semesterID: 8, startDate: "2035-09-01"),
            exam(3, semesterID: 8, startDate: "2035-09-01", examDate: "2036-01-10")
        ]))
        await model.load()
        XCTAssertEqual(model.exams.map(\.id), [1, 2, 3])
        XCTAssertEqual(model.semesters.map(\.id), [8, 7])

        model.semesterID = 8
        XCTAssertEqual(model.exams.map(\.id), [2, 3])
        XCTAssertNil(model.exams.first?.examDate)
        XCTAssertEqual(model.exam(id: 1)?.section.semesterId, 7)
        XCTAssertEqual(model.exam(id: 1)?.section.jwId, 42)
        XCTAssertNil(model.exam(id: 1001), "Exam JWIDs must not resolve as internal detail IDs")
        model.semesterID = 7
        XCTAssertEqual(model.exams.map(\.id), [1])
        model.semesterID = nil
        XCTAssertEqual(model.exams.map(\.id), [1, 2, 3])
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    @MainActor
    func testFailedRefreshPreservesSelectedSemesterAndCanonicalSnapshot() async {
        let model = ServerWorkspaceExamsModel(client: client)
        MockURLProtocol.stubJSON(page([exam(1, semesterID: 7, startDate: "2034-09-01")]))
        await model.load()
        model.semesterID = 7
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.semesterID, 7)
        XCTAssertEqual(model.exams.map(\.id), [1])
        XCTAssertEqual(model.semesters.map(\.id), [7])
        XCTAssertNotNil(model.exam(id: 1))
        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.isLoading)

        MockURLProtocol.stubJSON(page([exam(2, semesterID: 7, startDate: "2034-09-01")]))
        await model.load()
        XCTAssertEqual(model.exams.map(\.id), [2])
        XCTAssertNil(model.exam(id: 1))
        XCTAssertNil(model.error)
    }

    @MainActor
    func testLogoutImmediatelyHidesExamDetailsAndSemesterHistory() async {
        let model = ServerWorkspaceExamsModel(client: client)
        MockURLProtocol.stubJSON(page([exam(1, semesterID: 7, startDate: "2034-09-01")]))
        await model.load()
        XCTAssertEqual(model.exams.map(\.id), [1])
        model.semesterID = 7
        client.clearTokens()
        XCTAssertTrue(model.exams.isEmpty)
        XCTAssertTrue(model.semesters.isEmpty)
        XCTAssertNil(model.exam(id: 1))
        let before = MockURLProtocol.capturedRequests.count
        await model.load()
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, before)
        XCTAssertNil(model.semesterID)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor
    func testLogoutDuringReadClearsPreviousSnapshotWithoutPublishingError() async throws {
        let model = ServerWorkspaceExamsModel(client: client)
        MockURLProtocol.stubJSON(page([exam(1, semesterID: 7, startDate: "2034-09-01")]))
        await model.load()
        XCTAssertEqual(model.exams.map(\.id), [1])
        model.semesterID = 7
        let client = client!
        let data = try JSONSerialization.data(withJSONObject: page([
            exam(2, semesterID: 8, startDate: "2035-09-01")
        ]))
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, data)
        }
        await model.load()
        XCTAssertTrue(model.exams.isEmpty)
        XCTAssertTrue(model.semesters.isEmpty)
        XCTAssertNil(model.semesterID)
        XCTAssertNil(model.exam(id: 1))
        XCTAssertNil(model.exam(id: 2))
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
    }

    func testUnknownEndTimeKeepsTodaysExamUpcomingUntilNextShanghaiDay() throws {
        let unknown = try decode(exam(1, semesterID: 8, startDate: "2035-09-01"))
        let dayOnly = try decode(exam(2, semesterID: 8, startDate: "2035-09-01", examDate: "2035-09-15"))
        let timed = try decode(exam(3, semesterID: 8, startDate: "2035-09-01", examDate: "2035-09-15", endTime: 1100))
        let beforeEnd = try XCTUnwrap(ISO8601DateFormatter().date(from: "2035-09-15T10:59:59+08:00"))
        let atEnd = beforeEnd.addingTimeInterval(1)
        let lateToday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2035-09-15T23:59:59+08:00"))
        XCTAssertFalse(unknown.isPast(at: lateToday))
        XCTAssertFalse(dayOnly.isPast(at: lateToday))
        XCTAssertTrue(dayOnly.isPast(at: lateToday.addingTimeInterval(1)))
        XCTAssertFalse(timed.isPast(at: beforeEnd))
        XCTAssertTrue(timed.isPast(at: atEnd))
    }

    private func exam(_ id: Int, semesterID: Int, startDate: String,
                      examDate: String? = nil, endTime: Int? = nil) -> [String: Any] {
        ["id": id, "jwId": id + 1000, "sectionId": 7,
         "examDate": examDate.map { "\($0)T00:00:00+08:00" } as Any? ?? NSNull(),
         "endTime": endTime as Any? ?? NSNull(),
         "examRooms": [],
         "section": ["id": 7, "jwId": 42, "code": "MATH101.01", "courseId": 3,
                     "semesterId": semesterID,
                     "course": ["id": 3, "jwId": 99, "code": "MATH101", "nameCn": "数学"],
                     "semester": ["id": semesterID, "code": "semester-\(semesterID)",
                                  "nameCn": "Semester \(semesterID)", "startDate": "\(startDate)T00:00:00+08:00"]]]
    }

    private func page(_ exams: [[String: Any]]) -> [String: Any] {
        ["data": exams, "pagination": ["page": 1, "pageSize": 100,
                                      "total": exams.count, "totalPages": 1]]
    }

    private func decode(_ json: [String: Any]) throws -> ServerWorkspaceExam {
        try client.decoder.decode(ServerWorkspaceExam.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
