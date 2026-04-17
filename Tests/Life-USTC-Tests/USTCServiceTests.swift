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

    func testDecodeBBCalendarEvents() throws {
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

        let events = try JSONDecoder().decode([BBCalendarEventDTO].self, from: json)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].title, "Homework 1")
        XCTAssertEqual(events[0].calendarNameLocalizable?.rawValue, "Linear Algebra")
        XCTAssertEqual(events[1].id, "evt-2")
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

    // MARK: - AAS Course Table

    func testDecodeAASCourseTable() throws {
        let json = """
        {"lessonIds": [101, 102, 103], "studentTableVm": {"semesterId": 301, "id": 12345}}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AASCourseTableDTO.self, from: json)
        XCTAssertEqual(response.lessonIds, [101, 102, 103])
        XCTAssertEqual(response.studentTableVm?.semesterId, 301)
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
