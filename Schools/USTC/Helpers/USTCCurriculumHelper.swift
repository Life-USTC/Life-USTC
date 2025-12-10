import Foundation
import SwiftData
import SwiftUI
import SwiftyJSON

@MainActor
func updateCourse(semester: Semester, courseIDs: [Int]) async throws {
    for courseID in courseIDs {
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "\(Constants.ustcStaticURLPrefix)/curriculum/\(semester.jw_id)/\(courseID).json")!
        )
        let json = try JSON(data: data)

        let courseID = Int(json["id"].intValue)
        let courseName = json["name"].stringValue
        let courseCode = json["courseCode"].stringValue
        let lessonCode = json["lessonCode"].stringValue
        let teacherName = json["teacherName"].stringValue
        let detailText = json["detailText"].string
        let credit = json["credit"].doubleValue
        let dateTimePlacePersonText = json["dateTimePlacePersonText"].string

        let course = try SwiftDataStack.modelContext.upsert(
            predicate: #Predicate<Course> { $0.jw_id == courseID },
            update: { existing in
                existing.name = courseName
                existing.courseCode = courseCode
                existing.lessonCode = lessonCode
                existing.teacherName = teacherName
                existing.detailText = detailText
                existing.credit = credit
                existing.additionalInfo = [:]
                existing.dateTimePlacePersonText = dateTimePlacePersonText
                existing.semester = semester

                for lecture in existing.lectures {
                    SwiftDataStack.modelContext.delete(lecture)
                }
                existing.lectures = []
            },
            create: {
                let newCourse = Course(
                    jw_id: courseID,
                    name: courseName,
                    courseCode: courseCode,
                    lessonCode: lessonCode,
                    teacherName: teacherName,
                    description: detailText,
                    credit: credit,
                    additionalInfo: [:],
                    dateTimePlacePersonText: dateTimePlacePersonText
                )
                newCourse.semester = semester
                return newCourse
            }
        )

        for lectureJSON in json["lectures"].arrayValue {
            let lecture = Lecture(
                startDate: Date(timeIntervalSince1970: lectureJSON["startDate"].doubleValue),
                endDate: Date(timeIntervalSince1970: lectureJSON["endDate"].doubleValue),
                name: lectureJSON["name"].stringValue,
                location: lectureJSON["location"].stringValue,
                teacherName: lectureJSON["teacherName"].stringValue,
                periods: lectureJSON["periods"].doubleValue,
                additionalInfo: [:],
                startIndex: lectureJSON["startIndex"].int,
                endIndex: lectureJSON["endIndex"].int
            )

            SwiftDataStack.modelContext.insert(lecture)
            lecture.course = course
            course.lectures.append(lecture)
        }

        try! SwiftDataStack.modelContext.save()
    }
}

@MainActor
func updateUnderGraduateCurriculum(semester: Semester) async throws {
    @LoginClient(.ustcAAS) var ustcAASClient: USTCAASClient
    @AppStorage("USTCAdditionalCourseIDList") var additionalCourseIDList: [String: [Int]] = [:]

    if try await !_ustcAASClient.requireLogin() {
        throw BaseError.runtimeError("UstcUgAAS Not logined")
    }

    let studentID = try await {
        let (_, response) = try await URLSession.shared.data(
            from: URL(
                string: "https://jw.ustc.edu.cn/for-std/course-table"
            )!
        )

        return response.url?.absoluteString
            .matches(of: try! Regex(#"\d+"#))
            .first
            .map({ String($0.0) })
    }()

    guard let studentID else {
        throw BaseError.runtimeError("Cannot get student ID")
    }

    let courseIDs = try await {
        let (data, _) = try await URLSession.shared.data(
            from: URL(
                string:
                    "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=\(semester.jw_id)&dataId=\(studentID)"
            )!
        )
        let json = try JSON(data: data)
        var courseIDs = json["lessonIds"].arrayValue.map(\.intValue)

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

    let course_names = try await {
        let (data, _) = try await URLSession.shared.data(
            from: URL(
                string:
                    "https://app.ustc.edu.cn/xkjg/wap/default/get-index"
            )!
        )
        let json = try JSON(data: data)
        return json["d"]["lists"].arrayValue.map { $0["course_name"].stringValue }
    }()

    let courseCodeRegex = /\((.*?)\)/

    let courseCodes = course_names.compactMap { name -> String? in
        let match = try? courseCodeRegex.firstMatch(in: name)
        return match.map { String($0.1) }
    }

    let courseIDs = try await {
        let (semester_data, _) = try await URLSession.shared.data(
            from:
                URL(string: "\(Constants.ustcStaticURLPrefix)/curriculum/\(semester.jw_id)/courses.json")!
        )
        let json = try JSON(data: semester_data)
        let allCourses = json.arrayValue
        var courseIDs =
            allCourses
            .filter {
                courseCodes.contains($0["lessonCode"].stringValue)
                    || courseCodes.contains($0["lesson_code"].stringValue)
            }
            .map { $0["id"].intValue }

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
        @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate

        if SwiftDataStack.isPresentingDemo { return }

        let curriculum = try SwiftDataStack.modelContext.upsert(
            predicate: #Predicate<Curriculum> { $0.uniqueID == 0 },
            update: { _ in },
            create: { Curriculum() }
        )
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "\(Constants.ustcStaticURLPrefix)/curriculum/semesters.json")!
        )
        try! SwiftDataStack.modelContext.save()

        let json = try JSON(data: data)
        for semesterJSON in json.arrayValue {
            let semesterID = semesterJSON["id"].stringValue
            let semesterName = semesterJSON["name"].stringValue
            let semesterStartDate = Date(timeIntervalSince1970: semesterJSON["startDate"].doubleValue)
            let semesterEndDate = Date(timeIntervalSince1970: semesterJSON["endDate"].doubleValue)

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
    }
}
