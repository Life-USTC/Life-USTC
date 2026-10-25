import Foundation
import LifeClientCore
import SwiftData
import SwiftUI

@MainActor
func updateCourse(
    semester: Semester,
    courseIDs: [Int],
    service: USTCStaticService = USTCStaticService(),
    context: ModelContext? = nil
) async throws {
    for courseID in courseIDs {
        let parsed = try await service.fetchCourse(semesterId: semester.jw_id, courseId: courseID)
        let courseID = parsed.id
        let context = context ?? SwiftDataStack.modelContext

        let course = try context.upsert(
            predicate: #Predicate<Course> { $0.jw_id == courseID },
            update: { existing in
                existing.name = parsed.name
                existing.courseCode = parsed.courseCode
                existing.lessonCode = parsed.lessonCode
                existing.teacherName = parsed.teacherName
                existing.detailText = parsed.detailText
                existing.credit = parsed.credit
                existing.additionalInfo = [:]
                existing.dateTimePlacePersonText = parsed.dateTimePlacePersonText
                existing.semester = semester

                for lecture in existing.lectures {
                    context.delete(lecture)
                }
                existing.lectures = []
            },
            create: {
                let newCourse = Course(
                    jw_id: courseID,
                    name: parsed.name,
                    courseCode: parsed.courseCode,
                    lessonCode: parsed.lessonCode,
                    teacherName: parsed.teacherName,
                    description: parsed.detailText,
                    credit: parsed.credit,
                    additionalInfo: [:],
                    dateTimePlacePersonText: parsed.dateTimePlacePersonText
                )
                newCourse.semester = semester
                return newCourse
            }
        )

        for item in parsed.lectures {
            let lecture = Lecture(
                startDate: Date(timeIntervalSince1970: item.startDate),
                endDate: Date(timeIntervalSince1970: item.endDate),
                name: item.name,
                location: item.location,
                teacherName: item.teacherName,
                periods: item.periods,
                additionalInfo: [:],
                startIndex: item.startIndex,
                endIndex: item.endIndex
            )

            context.insert(lecture)
            lecture.course = course
            course.lectures.append(lecture)
        }

        try! context.save()
    }
}

@MainActor
func updateUnderGraduateCurriculum(semester: Semester) async throws {
    @LoginClient(.ustcAAS) var ustcAASClient: USTCAASClient
    @AppStorage("USTCAdditionalCourseIDList") var additionalCourseIDList: [String: [Int]] = [:]

    if try await !_ustcAASClient.requireLogin() {
        throw BaseError.runtimeError("UstcUgAAS Not logined")
    }

    let service = USTCAASService()
    let studentID = try await service.fetchStudentID()
    let courseIDs = try await {
        var courseIDs = try await service.fetchLessonIDs(semesterID: semester.jw_id, studentID: studentID)

        if additionalCourseIDList.keys.contains(semester.jw_id) {
            courseIDs = Array(Set(courseIDs + additionalCourseIDList[semester.jw_id]!))
        }

        return courseIDs
    }()

    try await updateCourse(semester: semester, courseIDs: courseIDs)
}

@MainActor
func updateGraduateCurriculum(semester: Semester) async throws {
    @AppStorage("USTCAdditionalCourseIDList") var additionalCourseIDList: [String: [Int]] = [:]
    @LoginClient(.ustcCAS) var casClient: USTCCASClient

    if !(try await _casClient.requireLogin()) {
        throw BaseError.runtimeError("UstcCAS Not logined")
    }

    _ = try await URLSession.shared.data(
        from: URL(
            string:
                "https://app.ustc.edu.cn/a_ustc/api/cas/index?redirect=https://app.ustc.edu.cn/site/examManage/index&from=wap"
        )!
    )

    _ = try await URLSession.shared.data(
        from: URL(
            string:
                "https://id.ustc.edu.cn/cas/login?service=https://app.ustc.edu.cn/a_ustc/api/cas/index?redirect=https%3A%2F%2Fapp.ustc.edu.cn%2Fsite%2FtimeTableQuery%2Findex&from=wap"
        )!
    )

    let courseIDs = try await {
        var courseIDs = try await USTCStaticService().fetchGraduateCourseIDs(semesterId: semester.jw_id)

        if additionalCourseIDList.keys.contains(semester.jw_id) {
            courseIDs = Array(Set(courseIDs + additionalCourseIDList[semester.jw_id]!))
        }

        return courseIDs
    }()

    try await updateCourse(semester: semester, courseIDs: courseIDs)
}

extension USTCSchool {
    @MainActor
    static func updateCurriculum() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        // Prefer server data when authenticated
        if ServerClient.shared.isAuthenticated {
            AppLogger.logger(for: "USTCCurriculum").info("Using server for curriculum update")
            try await ServerDataProvider.updateCurriculum()
            return
        }

        // Fall back to legacy USTC scraping
        AppLogger.logger(for: "USTCCurriculum").info("Using USTC scraping for curriculum update")
        try await updateCurriculumFromUSTC()
    }

    @MainActor
    static func updateCurriculumFromUSTC() async throws {
        @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate

        let curriculum = try SwiftDataStack.modelContext.upsert(
            predicate: #Predicate<Curriculum> { $0.uniqueID == 0 },
            update: { _ in },
            create: { Curriculum() }
        )
        let data = try await USTCStaticService().fetchSemestersData()
        try! SwiftDataStack.modelContext.save()

        for item in try USTCStatic.parseSemesters(data) {
            let semesterID = item.id
            let semesterName = item.name
            let semesterStartDate = Date(timeIntervalSince1970: item.startDate)
            let semesterEndDate = Date(timeIntervalSince1970: item.endDate)

            let semester = try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<Semester> { $0.jw_id == semesterID },
                update: { existing in
                    existing.name = semesterName
                    existing.startDate = semesterStartDate
                    existing.endDate = semesterEndDate
                },
                create: {
                    Semester(
                        jw_id: semesterID,
                        name: semesterName,
                        startDate: semesterStartDate,
                        endDate: semesterEndDate
                    )
                }
            )

            semester.curriculum = curriculum
            try! SwiftDataStack.modelContext.save()

            switch ustcStudentType {
            case .undergraduate:
                try await updateUnderGraduateCurriculum(semester: semester)
            case .graduate:
                if semester.isCurrent {
                    try await updateGraduateCurriculum(semester: semester)
                }
            }
        }

        // Push scraped curriculum data to server (best-effort, non-blocking)
        ServerSync.syncCurriculumInBackground()
    }
}
