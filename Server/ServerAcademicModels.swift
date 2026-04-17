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
struct ServerScheduleRef: Codable, Identifiable {
    let id: Int
    let periods: Int?
    let date: String?
    let weekday: Int
    let startTime: String
    let endTime: String
    let weekIndex: Int?
    let startUnit: Int?
    let endUnit: Int?
    let customPlace: String?
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
    let startTime: String  // "HH:MM"
    let endTime: String    // "HH:MM"
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
    let examBatch: NamedEntity?
    let examRooms: [ServerExamRoom]?
}

struct ServerExamRoom: Codable, Identifiable {
    let id: Int
    let roomCode: String?
    let seatCount: Int?
}
