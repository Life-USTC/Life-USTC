//
//  USTCServiceTests.swift
//  Life-USTC-Tests
//
//  Tests for USTC service response parsing with fixture data.
//

import XCTest
@testable import Life_USTC

final class USTCModelTests: XCTestCase {

    // MARK: - Blackboard Calendar Events

    func testBlackboardServicePreservesSelectedEventFields() async throws {
        let json = """
        [
            {
                "id": "evt-1",
                "title": "Homework 1",
                "startDate": "2026-03-01T00:00:00.000Z",
                "endDate": "2026-03-15T23:59:59.000Z",
                "calendarNameLocalizable": {"rawValue": "Linear Algebra"}
            },
            {
                "id": "evt-2",
                "title": "Lab Report",
                "startDate": "2026-03-10T00:00:00.000Z",
                "endDate": "2026-03-20T23:59:59.000Z",
                "calendarNameLocalizable": {"rawValue": "Physics"}
            }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(json)
        let events = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).fetchCalendarEvents()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].title, "Homework 1")
        XCTAssertEqual(events[0].courseName, "Linear Algebra")
        XCTAssertEqual(events[1].endDate, "2026-03-20T23:59:59.000Z")
    }

    func testBBDateParsing() {
        let date = USTCBlackboardService.parseDate("2026-03-15T23:59:59.000Z")
        XCTAssertNotNil(date)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            in: TimeZone(abbreviation: "UTC")!,
            from: date!
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
    }

    // MARK: - Catalog Semesters

    func testDecodeCatalogSemesters() throws {
        let json = """
        [
            {"id": 301, "name": "2025秋", "nameEn": "2025 Fall", "startDate": "2025-09-01", "endDate": "2026-01-15"},
            {"id": 302, "name": "2026春", "nameEn": "2026 Spring", "startDate": "2026-02-15", "endDate": "2026-07-01"}
        ]
        """.data(using: .utf8)!

        let semesters = try JSONDecoder().decode([CatalogSemesterDTO].self, from: json)
        XCTAssertEqual(semesters.count, 2)
        XCTAssertEqual(semesters[0].id, 301)
        XCTAssertEqual(semesters[0].name, "2025秋")
        XCTAssertEqual(semesters[1].nameEn, "2026 Spring")
    }

    // MARK: - Catalog Lessons

    func testDecodeCatalogLessons() throws {
        let json = """
        [
            {
                "id": 1001,
                "code": "MATH1001.01",
                "courseCode": "MATH1001",
                "courseName": "高等数学A1",
                "credits": 6.0,
                "teacherName": "张三",
                "deptName": "数学科学学院",
                "scheduleText": "周一3-4, 周三1-2"
            }
        ]
        """.data(using: .utf8)!

        let lessons = try JSONDecoder().decode([CatalogLessonDTO].self, from: json)
        XCTAssertEqual(lessons.count, 1)
        XCTAssertEqual(lessons[0].courseName, "高等数学A1")
        XCTAssertEqual(lessons[0].credits, 6.0)
        XCTAssertEqual(lessons[0].teacherName, "张三")
    }

    // MARK: - Static Semester

    func testDecodeStaticSemesters() throws {
        let json = """
        [
            {"id": "301", "name": "2025秋", "startDate": 1725148800, "endDate": 1737014400},
            {"id": "302", "name": "2026春", "startDate": 1739577600, "endDate": 1751328000}
        ]
        """.data(using: .utf8)!

        let semesters = try JSONDecoder().decode([StaticSemesterDTO].self, from: json)
        XCTAssertEqual(semesters.count, 2)
        XCTAssertEqual(semesters[0].id, "301")
        XCTAssertEqual(semesters[0].name, "2025秋")
    }

    // MARK: - Static Course

    func testDecodeStaticCourse() throws {
        let json = """
        {
            "id": 5001,
            "name": "线性代数",
            "courseCode": "MATH2001",
            "lessonCode": "MATH2001.01",
            "teacherName": "李四",
            "detailText": "Required course",
            "credit": 4.0,
            "dateTimePlacePersonText": "周二5-6节 3A409",
            "lectures": [
                {
                    "startDate": 1725235200,
                    "endDate": 1725242400,
                    "name": "Lecture 1",
                    "location": "3A409",
                    "teacherName": "李四",
                    "periods": 2.0,
                    "startIndex": 5,
                    "endIndex": 6
                }
            ]
        }
        """.data(using: .utf8)!

        let course = try JSONDecoder().decode(StaticCourseDTO.self, from: json)
        XCTAssertEqual(course.name, "线性代数")
        XCTAssertEqual(course.lessonCode, "MATH2001.01")
        XCTAssertEqual(course.lectures?.count, 1)
        XCTAssertEqual(course.lectures?[0].location, "3A409")
        XCTAssertEqual(course.lectures?[0].startIndex, 5)
    }

    // MARK: - Score Response

    func testDecodeAASScoreEntries() throws {
        let json = """
        {
            "courseNameCh": "高等数学",
            "courseCode": "MATH1001",
            "lessonCode": "MATH1001.01",
            "semesterAssoc": "301",
            "semesterCh": "2025秋",
            "credits": "6.0",
            "gp": "4.3",
            "scoreCh": "95"
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(AASScoreEntryDTO.self, from: json)
        XCTAssertEqual(entry.courseNameCh, "高等数学")
        XCTAssertEqual(entry.credits, "6.0")
        XCTAssertEqual(entry.gp, "4.3")
        XCTAssertEqual(entry.scoreCh, "95")
    }

    // MARK: - Service with Mock Session

    func testCatalogServiceFetchSemesters() async throws {
        MockURLProtocol.reset()
        let semestersJSON = """
        [{"id":1,"name":"2025秋"},{"id":2,"name":"2026春"}]
        """.data(using: .utf8)!

        MockURLProtocol.stubData(semestersJSON)
        let service = USTCCatalogService(session: MockURLProtocol.mockSession())

        let semesters = try await service.fetchSemesters()
        XCTAssertEqual(semesters.count, 2)
        XCTAssertEqual(semesters[0].name, "2025秋")
    }

    func testBlackboardServiceFetchEvents() async throws {
        MockURLProtocol.reset()
        let eventsJSON = """
        [{"id":"e1","title":"HW1","endDate":"2026-03-15T23:59:59.000Z","calendarNameLocalizable":{"rawValue":"Math"}}]
        """.data(using: .utf8)!

        MockURLProtocol.stubData(eventsJSON)
        let service = USTCBlackboardService(session: MockURLProtocol.mockSession())

        let events = try await service.fetchCalendarEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "HW1")
    }

    func testAASServiceFetchLessonIDs() async throws {
        MockURLProtocol.reset()
        let tableJSON = """
        {"lessonIds":[10,20,30]}
        """.data(using: .utf8)!

        MockURLProtocol.stubData(tableJSON)
        let service = USTCAASService(session: MockURLProtocol.mockSession())

        let ids = try await service.fetchLessonIDs(semesterID: "301", studentID: "12345")
        XCTAssertEqual(ids, [10, 20, 30])
    }

    func testAASServiceUsesSharedRedirectAndNestedTable() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.requestHandler = { request in
            if request.url!.path == "/for-std/course-table" {
                return (HTTPURLResponse(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/info/0012345")!,
                    statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
            XCTAssertEqual(request.url!.absoluteString,
                "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=301&dataId=0012345")
            let data = Data(#"{"studentTableVm":{"lessonIds":[30,10,30]},"lessonIds":[90]}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = USTCAASService(session: MockURLProtocol.mockSession())
        let studentID = try await service.fetchStudentID()
        XCTAssertEqual(studentID, "0012345")
        let ids = try await service.fetchLessonIDs(semesterID: "301", studentID: studentID)
        XCTAssertEqual(ids, [10, 30])
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testAASServiceRetainsEmptyTable() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data(#"{"lessonIds":[]}"#.utf8))
        let service = USTCAASService(session: MockURLProtocol.mockSession())
        let ids = try await service.fetchLessonIDs(semesterID: "301", studentID: "12345")
        XCTAssertTrue(ids.isEmpty)
    }

    func testAASServicePropagatesMalformedCourseTable() async {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data("{".utf8))
        let service = USTCAASService(session: MockURLProtocol.mockSession())
        do {
            _ = try await service.fetchLessonIDs(semesterID: "301", studentID: "12345")
            XCTFail("Malformed course table must fail")
        } catch {}
    }

    func testAASScoreServicePreservesRankAndMissingGradePoint() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data(#"{"overview":{"gpa":3.5},"stdGradeRank":{"majorName":"Mathematics","majorRank":2,"majorStdCount":50},"semesters":[{"scores":[{"courseNameCh":"Calculus","courseCode":"MATH101","lessonCode":"MATH101.01","semesterAssoc":301,"semesterCh":"Fall","credits":4,"gp":"","scoreCh":95},{"courseNameCh":"Physics","gp":"3.7","credits":"2.0"}]}]}"#.utf8))
        let report = try await USTCAASService(session: MockURLProtocol.mockSession()).fetchScores()
        XCTAssertEqual(report.gpa, 3.5)
        XCTAssertEqual(report.majorName, "Mathematics")
        XCTAssertEqual(report.majorRank, 2)
        XCTAssertEqual(report.majorStdCount, 50)
        XCTAssertEqual(report.entries.map(\.courseName), ["Calculus", "Physics"])
        XCTAssertEqual(report.entries[0].semesterID, "301")
        XCTAssertEqual(report.entries[0].credits, 4)
        XCTAssertNil(report.entries[0].gradePoint)
        XCTAssertEqual(report.entries[0].score, "95")
        XCTAssertEqual(report.entries[1].gradePoint, 3.7)
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.absoluteString,
            "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?trainTypeId=1&semesterIds")
    }

    func testAASExamServicePreservesRoomColumnMapping() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data("""
        <table id="exams"><tbody><tr><td>MATH101.01</td><td>Final</td><td>Calculus</td>
        <td>2026-12-23 09:00-11:00</td><td>2201</td><td>Teaching Building</td><td>East</td><td>Bring ID</td></tr></tbody></table>
        """.utf8))
        let exams = try await USTCAASService(session: MockURLProtocol.mockSession()).fetchExams()
        let exam = try XCTUnwrap(exams.first)
        XCTAssertEqual(exams.count, 1)
        XCTAssertEqual(exam.lessonCode, "MATH101.01")
        XCTAssertEqual(exam.examType, "Final")
        XCTAssertEqual(exam.courseName, "Calculus")
        XCTAssertEqual(exam.dateTime, "2026-12-23 09:00-11:00")
        XCTAssertEqual(exam.roomName, "2201")
        XCTAssertEqual(exam.buildingName, "Teaching Building")
        XCTAssertEqual(exam.district, "East")
        XCTAssertEqual(exam.detail, "Bring ID")
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/for-std/exam-arrange")
    }

    func testScoreAndHomeworkServicesPropagateInvalidResponses() async {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        MockURLProtocol.stubData(Data("{".utf8))
        let session = MockURLProtocol.mockSession()
        do {
            _ = try await USTCAASService(session: session).fetchScores()
            XCTFail("Malformed scores must fail")
        } catch {}
        do {
            _ = try await USTCBlackboardService(session: session).fetchCalendarEvents()
            XCTFail("Malformed homework must fail")
        } catch {}
    }

    func testStaticServiceFetchCourse() async throws {
        MockURLProtocol.reset()
        let courseJSON = """
        {"id":1,"name":"Test","courseCode":"T001","lessonCode":"T001.01","teacherName":"X","lectures":[]}
        """.data(using: .utf8)!

        MockURLProtocol.stubData(courseJSON)
        let service = USTCStaticService(session: MockURLProtocol.mockSession())

        let course = try await service.fetchCourse(semesterId: "301", courseId: 1)
        XCTAssertEqual(course.name, "Test")
        XCTAssertEqual(course.lessonCode, "T001.01")
    }
}
