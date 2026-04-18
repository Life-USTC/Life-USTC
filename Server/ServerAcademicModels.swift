//
//  ServerAcademicModels.swift
//  Life@USTC
//
//  Created on 2026/4/18.
//

import Foundation

// MARK: - Shared Named Entity

/// Reusable model for category, department, campus, title, etc.
struct NamedEntity: Codable, Identifiable, Hashable {
    let id: Int
    let nameCn: String
    let nameEn: String?
}

// MARK: - Course

struct ServerCourseSummary: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let nameCn: String
    let nameEn: String?
    let category: NamedEntity?
    let classType: NamedEntity?
    let classify: NamedEntity?
    let educationLevel: NamedEntity?
    let gradation: NamedEntity?
    let type: NamedEntity?
}

struct ServerCourseDetail: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let nameCn: String
    let nameEn: String?
    let category: NamedEntity?
    let classType: NamedEntity?
    let classify: NamedEntity?
    let educationLevel: NamedEntity?
    let gradation: NamedEntity?
    let type: NamedEntity?
    let sections: [ServerCourseSectionRef]?
}

/// Section reference as embedded in course detail response.
struct ServerCourseSectionRef: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let credits: Double?
    let stdCount: Int?
    let limitCount: Int?
    let semester: ServerSemester?
    let campus: NamedEntity?
    let teachers: [ServerTeacherRef]?
}

// MARK: - Section

struct ServerSectionSummary: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let credits: Double?
    let period: Int?
    let stdCount: Int?
    let limitCount: Int?
    let course: ServerCourseSummary?
    let semester: ServerSemester?
    let campus: NamedEntity?
    let openDepartment: NamedEntity?
    let examMode: NamedEntity?
    let teachLanguage: NamedEntity?
    let teachers: [ServerTeacherRef]?
}

struct ServerSectionDetail: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let credits: Double?
    let period: Int?
    let stdCount: Int?
    let limitCount: Int?
    let course: ServerCourseSummary?
    let semester: ServerSemester?
    let campus: NamedEntity?
    let openDepartment: NamedEntity?
    let examMode: NamedEntity?
    let teachLanguage: NamedEntity?
    let roomType: NamedEntity?
    let teachers: [ServerTeacherRef]?
    let schedules: [ServerScheduleRef]?
    let scheduleGroups: [ServerScheduleGroup]?
    let exams: [ServerExamEntry]?
}

/// Minimal schedule reference within a section detail.
/// Note: In section detail responses, startTime/endTime are integers (e.g. 800 for 08:00).
/// In /api/schedules responses, they are formatted strings ("08:00").
struct ServerScheduleRef: Codable, Identifiable {
    let id: Int
    let periods: Int?
    let date: String?
    let weekday: Int
    let startTime: IntOrString
    let endTime: IntOrString
    let weekIndex: Int?
    let startUnit: Int?
    let endUnit: Int?
    let customPlace: String?
}

/// Decodes either an Int (from section detail) or String (from /api/schedules).
enum IntOrString: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                IntOrString.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected Int or String")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }

    /// Parsed hours and minutes.
    var components: (hour: Int, minute: Int) {
        switch self {
        case .int(let v):
            // e.g. 800 → 08:00, 1400 → 14:00
            return (v / 100, v % 100)
        case .string(let s):
            // e.g. "08:00"
            let parts = s.split(separator: ":")
            guard parts.count == 2,
                  let h = Int(parts[0]),
                  let m = Int(parts[1])
            else { return (0, 0) }
            return (h, m)
        }
    }
}

struct ServerScheduleGroup: Codable, Identifiable {
    let id: Int
    let name: String?
}

// MARK: - Teacher

/// Minimal teacher reference embedded in sections/schedules.
struct ServerTeacherRef: Codable, Identifiable {
    let id: Int
    let nameCn: String
    let nameEn: String?
    let code: String?
}

struct ServerTeacherSummary: Codable, Identifiable {
    let id: Int
    let code: String?
    let nameCn: String
    let nameEn: String?
    let email: String?
    let department: NamedEntity?
    let teacherTitle: NamedEntity?
    // swiftlint:disable:next identifier_name
    let _count: TeacherSectionCount?

    struct TeacherSectionCount: Codable {
        let sections: Int
    }
}

struct ServerTeacherDetail: Codable, Identifiable {
    let id: Int
    let code: String?
    let nameCn: String
    let nameEn: String?
    let email: String?
    let telephone: String?
    let mobile: String?
    let address: String?
    let department: NamedEntity?
    let teacherTitle: NamedEntity?
    let sections: [ServerSectionSummary]?
    // swiftlint:disable:next identifier_name
    let _count: ServerTeacherSummary.TeacherSectionCount?
}

// MARK: - Schedule (full, from GET /api/schedules)

struct ServerScheduleEntry: Codable, Identifiable {
    let id: Int
    let periods: Int?
    let date: String?
    let weekday: Int
    let startTime: IntOrString
    let endTime: IntOrString
    let weekIndex: Int?
    let startUnit: Int?
    let endUnit: Int?
    let customPlace: String?
    let room: ServerRoom?
    let teachers: [ServerTeacherRef]?
    let section: ServerScheduleSectionRef?
    let scheduleGroup: ServerScheduleGroup?
}

struct ServerRoom: Codable, Identifiable {
    let id: Int
    let name: String?
    let code: String?
    let namePrimary: String?
    let nameSecondary: String?
    let building: ServerBuilding?
    let roomType: NamedEntity?
}

struct ServerBuilding: Codable, Identifiable {
    let id: Int
    let name: String?
    let code: String?
    let namePrimary: String?
    let nameSecondary: String?
    let campus: NamedEntity?
}

/// Section reference embedded in schedule entries.
struct ServerScheduleSectionRef: Codable, Identifiable {
    let id: Int
    let jwId: Int
    let code: String
    let credits: Double?
    let course: ServerCourseSummary?
    let semester: ServerSemester?
}

// MARK: - Exam

struct ServerExamEntry: Codable, Identifiable {
    let id: Int
    let examDate: String?
    let startTime: Int?
    let endTime: Int?
    let examType: Int?
    let examMode: String?
    let examBatch: NamedEntity?
    let examRooms: [ServerExamRoom]?
}

struct ServerExamRoom: Codable, Identifiable {
    let id: Int
    let room: String?
    let count: Int?
}
