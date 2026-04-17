//
//  USTCModels.swift
//  Life@USTC
//
//  Typed DTO models for USTC API responses.
//  Uses "DTO" suffix to avoid collision with SwiftData @Model types.
//

import Foundation

// MARK: - AAS (jw.ustc.edu.cn)

/// Course table response from jw.ustc.edu.cn/for-std/course-table/get-data
struct AASCourseTableDTO: Codable {
    let lessonIds: [Int]?
    let studentTableVm: StudentTableVM?

    struct StudentTableVM: Codable {
        let semesterId: Int?
        let id: Int?
    }
}

/// Lesson search result from jw.ustc.edu.cn/for-std/lesson-search
struct AASLessonSearchDTO: Codable {
    let data: [AASLessonDTO]?
    let limit: Int?
    let offset: Int?
    let total: Int?
}

struct AASLessonDTO: Codable {
    let id: Int
    let courseId: Int?
    let code: String?
    let courseName: String?
    let credits: Double?
    let teacherAssignmentList: [TeacherAssignment]?

    struct TeacherAssignment: Codable {
        let id: Int?
        let teacherId: Int?
        let person: Person?

        struct Person: Codable {
            let nameZh: String?
            let nameEn: String?
        }
    }
}

/// Score response from jw.ustc.edu.cn/for-std/grade/sheet/getGradeList
struct AASScoreResponseDTO: Codable {
    let overview: ScoreOverview?
    let semesters: [AASScoreSemesterDTO]?
    let stdGradeRank: StdGradeRank?

    struct ScoreOverview: Codable {
        let gpa: Double?
    }

    struct StdGradeRank: Codable {
        let majorName: String?
        let majorRank: Int?
        let majorStdCount: Int?
    }
}

struct AASScoreSemesterDTO: Codable {
    let semester: AASScoreSemesterInfo?
    let scores: [AASScoreEntryDTO]?

    struct AASScoreSemesterInfo: Codable {
        let id: Int?
        let nameZh: String?
    }
}

struct AASScoreEntryDTO: Codable {
    let courseNameCh: String?
    let courseCode: String?
    let lessonCode: String?
    let semesterAssoc: String?
    let semesterCh: String?
    let credits: String?
    let gp: String?
    let scoreCh: String?
}

/// Exam data parsed from HTML at jw.ustc.edu.cn/for-std/exam-arrange
struct AASExamDTO {
    let lessonCode: String
    let typeName: String
    let courseName: String
    let dateTimeString: String
    let classRoomName: String
    let classRoomBuildingName: String
    let classRoomDistrict: String
    let detail: String
}

// MARK: - Blackboard (bb.ustc.edu.cn)

/// Calendar event from bb.ustc.edu.cn/webapps/calendar/calendarData/selectedCalendarEvents
struct BBCalendarEventDTO: Codable {
    let id: String?
    let title: String?
    let start: String?
    let end: String?
    let startDate: String?
    let endDate: String?
    let calendarNameLocalizable: CalendarName?

    struct CalendarName: Codable {
        let rawValue: String?
    }
}

// MARK: - Catalog (catalog.ustc.edu.cn)

/// Semester from catalog.ustc.edu.cn/api/teach/semester/list
struct CatalogSemesterDTO: Codable {
    let id: Int
    let name: String?
    let nameEn: String?
    let startDate: String?
    let endDate: String?
    let yearCode: String?
    let termCode: Int?
}

/// Lesson from catalog.ustc.edu.cn/api/teach/lesson/list-for-teach/{semesterId}
struct CatalogLessonDTO: Codable {
    let id: Int
    let code: String?
    let courseCode: String?
    let courseName: String?
    let credits: Double?
    let teacherName: String?
    let deptName: String?
    let scheduleText: String?
}

/// Exam from catalog.ustc.edu.cn/api/teach/exam/list/{semesterId}
struct CatalogExamDTO: Codable {
    let id: Int?
    let lessonCode: String?
    let courseName: String?
    let examTime: String?
    let examPlace: String?
    let examType: String?
}

// MARK: - Static Data (static.life-ustc.tiankaima.dev)

/// Semester list from static server
struct StaticSemesterDTO: Codable {
    let id: String
    let name: String
    let startDate: Double
    let endDate: Double
}

/// Course from static curriculum JSON
struct StaticCourseDTO: Codable {
    let id: Int
    let name: String
    let courseCode: String
    let lessonCode: String
    let teacherName: String
    let detailText: String?
    let credit: Double?
    let dateTimePlacePersonText: String?
    let lectures: [StaticLectureDTO]?

    // Some JSON uses snake_case for lessonCode
    enum CodingKeys: String, CodingKey {
        case id, name, courseCode, lessonCode, teacherName
        case detailText, credit, dateTimePlacePersonText, lectures
    }

    // Handle alternate key name
    var effectiveLessonCode: String {
        lessonCode
    }
}

struct StaticLectureDTO: Codable {
    let startDate: Double
    let endDate: Double
    let name: String?
    let location: String?
    let teacherName: String?
    let periods: Double?
    let startIndex: Int?
    let endIndex: Int?
}

/// Course list item (minimal) for searching
struct StaticCourseListItemDTO: Codable {
    let id: Int
    let lessonCode: String?
    let lesson_code: String?

    var effectiveLessonCode: String {
        lessonCode ?? lesson_code ?? ""
    }
}
