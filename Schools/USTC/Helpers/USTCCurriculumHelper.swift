import Foundation
import SwiftData
import SwiftUI
import SwiftyJSON

@MainActor
func updateCouse(semsester: Semester, courseIDs: [Int]) async throws {
    for courseID in courseIDs {
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "\(Constants.staticURLPrefix)/curriculum/\(semsester.id)/\(courseID).json")!
        )
        let json = try JSON(data: data)

        //        try! SwiftDataStack.modelContext.delete(model: Course.self, where: #Predicate<Course> { $0.id == courseID })
        //        try! SwiftDataStack.modelContext.delete(model: Lecture.self)

        let course = Course(
            semester: semsester,
            id: Int(json["id"].intValue),
            name: json["name"].stringValue,
            courseCode: json["courseCode"].stringValue,
            lessonCode: json["lessonCode"].stringValue,
            teacherName: json["teacherName"].stringValue,
            description: json["detailText"].string,
            credit: json["credit"].doubleValue,
            additionalInfo: [:],
            dateTimePlacePersonText: json["dateTimePlacePersonText"].string
        )
        SwiftDataStack.modelContext.insert(course)
        try SwiftDataStack.modelContext.save()

        for lecture in course.lectures ?? [] {
            debugPrint(lecture)
        }

        for lectureJSON in json["lectures"].arrayValue {
            let lecture = Lecture(
                course: course,
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
        }

        try SwiftDataStack.modelContext.save()
    }
}

@MainActor
func updateUnderGraduateCurriculum(semester: Semester) async throws {
    @LoginClient(.ustcAAS) var ustcAASClient: UstcAASClient
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
                    "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=\(semester.id)&dataId=\(studentID)"
            )!
        )
        let json = try JSON(data: data)
        var courseIDs = json["lessonIds"].arrayValue.map(\.intValue)

        if additionalCourseIDList.keys.contains(semester.id) {
            courseIDs = Array(Set(courseIDs + additionalCourseIDList[semester.id]!))
        }

        return courseIDs
    }()

    try await updateCouse(semsester: semester, courseIDs: courseIDs)
}

@MainActor
func updateGraduateCurriculum(semester: Semester) async throws {
    @AppStorage("USTCAdditionalCourseIDList") var additionalCourseIDList: [String: [Int]] = [:]
    @LoginClient(.ustcCAS) var casClient: UstcCasClient

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
                URL(string: "\(Constants.staticURLPrefix)/curriculum/\(semester.id)/courses.json")!
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

        if additionalCourseIDList.keys.contains(semester.id) {
            courseIDs = Array(Set(courseIDs + additionalCourseIDList[semester.id]!))
        }

        return courseIDs
    }()

    try await updateCouse(semsester: semester, courseIDs: courseIDs)
}

extension USTCSchool {
    @MainActor
    static func updateCurriculum() async throws {
        @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate

        let curriculum = Curriculum()
        try! SwiftDataStack.modelContext.delete(model: Curriculum.self)
        SwiftDataStack.modelContext.insert(curriculum)

        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "\(Constants.staticURLPrefix)/curriculum/semesters.json")!
        )

        let json = try JSON(data: data)
        var semesters: [Semester] = []
        for semesterJSON in json.arrayValue {
            let semester = Semester(
                curriculum: curriculum,
                id: semesterJSON["id"].stringValue,
                name: semesterJSON["name"].stringValue,
                startDate: Date(timeIntervalSince1970: semesterJSON["startDate"].doubleValue),
                endDate: Date(timeIntervalSince1970: semesterJSON["endDate"].doubleValue)
            )

            SwiftDataStack.modelContext.insert(semester)
            try SwiftDataStack.modelContext.save()
            semesters.append(semester)
        }
        for semester in semesters {
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
