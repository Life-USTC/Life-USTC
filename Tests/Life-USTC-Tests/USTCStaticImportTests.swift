import SwiftData
import XCTest
@testable import Life_USTC

final class USTCStaticImportTests: XCTestCase {
    func testSemesterServicePreservesScalarDefaultsAndCustomBasePath() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data(#"[{"id":301,"name":false,"startDate":"1725148800","endDate":1737014400},{}]"#.utf8))

        let semesters = try await makeService().fetchSemesters()

        XCTAssertEqual(semesters.map(\.id), ["301", ""])
        XCTAssertEqual(semesters.map(\.name), ["false", ""])
        XCTAssertEqual(semesters.map(\.startDate), [1725148800, 0])
        XCTAssertEqual(semesters.map(\.endDate), [1737014400, 0])
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.absoluteString,
            "https://example.test/static/curriculum/semesters.json")
    }

    func testCourseListPreservesCanonicalAndLegacyCodesSeparately() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data(#"[{"id":"7","name":23,"courseCode":"MATH","lessonCode":"canonical","lesson_code":"legacy","teacherName":true},{"id":7,"lesson_code":"legacy-only"}]"#.utf8))

        let courses = try await makeService().fetchCourseList(semesterId: "301")

        XCTAssertEqual(courses.map(\.id), [7, 7])
        XCTAssertEqual(courses.map(\.lessonCode), ["canonical", ""])
        XCTAssertEqual(courses.map(\.legacyLessonCode), ["legacy", "legacy-only"])
        XCTAssertEqual(courses[0].name, "23")
        XCTAssertEqual(courses[0].courseCode, "MATH")
        XCTAssertEqual(courses[0].teacherName, "true")
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/static/curriculum/301/courses.json")
    }

    func testGraduateAppMatchesBothCodesInListOrderIncludingDuplicates() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.requestHandler = { request in
            let data: Data
            if request.url!.host == "app.ustc.edu.cn" {
                data = Data(#"{"d":{"lists":[{"course_name":"Math(A)"},{"course_name":"Empty()"},{"course_name":"Ignored"}]}}"#.utf8)
            } else {
                data = Data(#"[{"id":8,"lessonCode":"A","lesson_code":"other"},{"id":7,"lessonCode":"other","lesson_code":"A"},{"id":8,"lessonCode":"A"},{"id":9,"lessonCode":"","lesson_code":"other"},{"id":10,"lessonCode":"other","lesson_code":"other"}]"#.utf8)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let ids = try await makeService().fetchGraduateCourseIDs(semesterId: "301")

        XCTAssertEqual(ids, [8, 7, 8, 9])
        XCTAssertEqual(MockURLProtocol.capturedRequests.compactMap { $0.url?.absoluteString }, [
            "https://app.ustc.edu.cn/xkjg/wap/default/get-index",
            "https://example.test/static/curriculum/301/courses.json",
        ])
    }

    func testMalformedGraduateAppStopsBeforeCourseListRequest() async {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data("{".utf8))

        do {
            _ = try await makeService().fetchGraduateCourseIDs(semesterId: "301")
            XCTFail("Malformed app response must fail before requesting static data")
        } catch {}

        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.host, "app.ustc.edu.cn")
    }

    func testMalformedGraduateCourseListFailsAfterAppRequest() async {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.requestHandler = { request in
            let data = request.url!.host == "app.ustc.edu.cn"
                ? Data(#"{"d":{"lists":[]}}"#.utf8) : Data("{".utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        do {
            _ = try await makeService().fetchGraduateCourseIDs(semesterId: "301")
            XCTFail("Malformed static list must fail even for an empty app course list")
        } catch {}

        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        XCTAssertEqual(MockURLProtocol.capturedRequests.last?.url?.path, "/static/curriculum/301/courses.json")
    }

    @MainActor
    func testCourseImportUsesResponseIdentityAndPreservesScalarAndOptionalFields() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let context = try makeContext()
        let semester = Semester(jw_id: "301", name: "Fall", startDate: .distantPast, endDate: .distantFuture)
        context.insert(semester)
        MockURLProtocol.stubData(Data(#"{"id":"7","name":23,"courseCode":"MATH","lessonCode":"MATH.01","teacherName":false,"detailText":"","description":"ignored","credit":"2.5","dateTimePlacePersonText":"Room","lectures":[{"startDate":"1725235200","endDate":1725242400,"name":10,"location":"3A409","teacherName":true,"periods":"2","startIndex":"5","endIndex":0}]}"#.utf8))

        try await updateCourse(semester: semester, courseIDs: [99], service: makeService(), context: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        let course = try XCTUnwrap(courses.first)
        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(course.jw_id, 7)
        XCTAssertEqual(course.name, "23")
        XCTAssertEqual(course.courseCode, "MATH")
        XCTAssertEqual(course.lessonCode, "MATH.01")
        XCTAssertEqual(course.teacherName, "false")
        XCTAssertEqual(course.detailText, "")
        XCTAssertEqual(course.credit, 2.5)
        XCTAssertEqual(course.dateTimePlacePersonText, "Room")
        XCTAssertEqual(course.semester?.persistentModelID, semester.persistentModelID)
        XCTAssertTrue(course.additionalInfo.isEmpty)
        let lecture = try XCTUnwrap(course.lectures.first)
        XCTAssertEqual(course.lectures.count, 1)
        XCTAssertEqual(lecture.startDate.timeIntervalSince1970, 1725235200)
        XCTAssertEqual(lecture.endDate.timeIntervalSince1970, 1725242400)
        XCTAssertEqual(lecture.name, "10")
        XCTAssertEqual(lecture.location, "3A409")
        XCTAssertEqual(lecture.teacherName, "true")
        XCTAssertEqual(lecture.periods, 2)
        XCTAssertNil(lecture.startIndex)
        XCTAssertEqual(lecture.endIndex, 0)
        XCTAssertTrue(lecture.additionalInfo.isEmpty)
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/static/curriculum/301/99.json")
    }

    @MainActor
    func testCourseReimportReplacesLecturesAndClearsAbsentFields() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let context = try makeContext()
        let semester = Semester(jw_id: "301", name: "Fall", startDate: .distantPast, endDate: .distantFuture)
        context.insert(semester)
        let service = makeService()
        MockURLProtocol.stubData(Data(#"{"id":7,"name":"Old","detailText":"Old detail","credit":4,"dateTimePlacePersonText":"Old room","lectures":[{"name":"Old lecture","startIndex":1}]}"#.utf8))
        try await updateCourse(semester: semester, courseIDs: [7], service: service, context: context)
        let course = try XCTUnwrap(try context.fetch(FetchDescriptor<Course>()).first)
        course.additionalInfo = ["old": "value"]
        let oldLectureID = try XCTUnwrap(course.lectures.first).persistentModelID
        MockURLProtocol.stubData(Data(#"{"id":7,"name":"New","description":"Must not become detailText","lectures":[{"name":"New lecture","startIndex":0,"endIndex":"0"}]}"#.utf8))

        try await updateCourse(semester: semester, courseIDs: [7], service: service, context: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 1)
        XCTAssertEqual(course.name, "New")
        XCTAssertEqual(course.courseCode, "")
        XCTAssertEqual(course.lessonCode, "")
        XCTAssertEqual(course.teacherName, "")
        XCTAssertNil(course.detailText)
        XCTAssertNil(course.dateTimePlacePersonText)
        XCTAssertEqual(course.credit, 0)
        XCTAssertTrue(course.additionalInfo.isEmpty)
        let lectures = try context.fetch(FetchDescriptor<Lecture>())
        XCTAssertEqual(lectures.count, 1)
        let lecture = try XCTUnwrap(lectures.first)
        XCTAssertNotEqual(lecture.persistentModelID, oldLectureID)
        XCTAssertEqual(lecture.name, "New lecture")
        XCTAssertEqual(lecture.startIndex, 0)
        XCTAssertNil(lecture.endIndex)
        XCTAssertEqual(course.lectures.map(\.persistentModelID), [lecture.persistentModelID])
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testMalformedCourseLeavesPriorImportUnchanged() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let context = try makeContext()
        let semester = Semester(jw_id: "301", name: "Fall", startDate: .distantPast, endDate: .distantFuture)
        context.insert(semester)
        let service = makeService()
        MockURLProtocol.stubData(Data(#"{"id":7,"name":"Existing","lectures":[{"name":"Existing lecture"}]}"#.utf8))
        try await updateCourse(semester: semester, courseIDs: [7], service: service, context: context)
        let course = try XCTUnwrap(try context.fetch(FetchDescriptor<Course>()).first)
        let lectureIDs = course.lectures.map(\.persistentModelID)
        MockURLProtocol.stubData(Data("{".utf8))

        do {
            try await updateCourse(semester: semester, courseIDs: [7], service: service, context: context)
            XCTFail("Malformed course must not replace stored data")
        } catch {}

        XCTAssertEqual(course.name, "Existing")
        XCTAssertEqual(course.lectures.map(\.persistentModelID), lectureIDs)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 1)
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testCourseImportRetainsCompletedCoursesWhenLaterResponseFails() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let context = try makeContext()
        let semester = Semester(jw_id: "301", name: "Fall", startDate: .distantPast, endDate: .distantFuture)
        context.insert(semester)
        MockURLProtocol.requestHandler = { request in
            let data = request.url!.lastPathComponent == "7.json"
                ? Data(#"{"id":7,"name":"Completed","lectures":[{"name":"Lecture"}]}"#.utf8)
                : Data("{".utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        do {
            try await updateCourse(semester: semester, courseIDs: [7, 7, 8], service: makeService(), context: context)
            XCTFail("Malformed later response must fail the import")
        } catch {}

        XCTAssertEqual(MockURLProtocol.capturedRequests.compactMap { $0.url?.lastPathComponent },
            ["7.json", "7.json", "8.json"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Course>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Lecture>()), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).first?.name, "Completed")
        XCTAssertFalse(context.hasChanges)
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

    private func makeService() -> USTCStaticService {
        USTCStaticService(session: MockURLProtocol.mockSession(), baseURL: URL(string: "https://example.test/static")!)
    }
}
