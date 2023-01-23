//
//  UstcUgAAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/16.
//

import SwiftSoup
import SwiftUI
import SwiftyJSON

/// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    static var main = UstcUgAASClient()
    static let semesterIDList: [String: String] =
        ["2021年秋季学期": "221",
         "2022年春季学期": "241",
         "2022年夏季学期": "261",
         "2022年秋季学期": "281",
         "2023年春季学期": "301"]
    static let semesterDateList: [String: Date] =
        ["2021年秋季学期": .init(timeIntervalSince1970: 1_630_771_200),
         "2022年春季学期": .init(timeIntervalSince1970: 1_642_608_000),
         "2022年夏季学期": .init(timeIntervalSince1970: 1_656_172_800),
         "2022年秋季学期": .init(timeIntervalSince1970: 1_661_616_000),
         "2023年春季学期": .init(timeIntervalSince1970: 1_677_945_600)]

    var semesterID: String = userDefaults.string(forKey: "semesterID") ?? "301"
    var semesterName: String {
        UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })!.key
    }

    var semesterDate: Date {
        UstcUgAASClient.semesterDateList.first(where: { $0.key == semesterName })!.value
    }

    var lastUpdatedCurriculum: Date?
    var courses: [Course] = []
    var curriculumJsonCache = JSON() // save&load as /document/ugaas_cache.json

    var lastUpdatedExams: Date?
    var exams: [Exam] = []

    var lastUpdatedScores: Date?
    var score: Score = .init()
    var scoreJsonCache = JSON() // save&load as /document/ugaas_score.json

    func loadCache() throws {
        let decoder = JSONDecoder()
        if let data = userDefaults.data(forKey: "UstcUgAASLastUpdatedCurriculum") {
            lastUpdatedCurriculum = try decoder.decode(Date?.self, from: data)
        }
        if let data = userDefaults.data(forKey: "UstcUgAASLastUpdateExams") {
            lastUpdatedExams = try decoder.decode(Date?.self, from: data)
        }
        if let data = userDefaults.data(forKey: "UstcUgAASLastUpdateScores") {
            lastUpdatedScores = try decoder.decode(Date?.self, from: data)
        }

        if let data = userDefaults.data(forKey: "UstcUgAASCurriculumCache") {
            curriculumJsonCache = try JSON(data: data)
        } else {
            Task {
                try await forceUpdateCurriculum()
            }
        }
        if let data = userDefaults.data(forKey: "UstcUgAASExamCache") {
            exams = try JSONDecoder().decode([Exam].self, from: data)
        } else {
            Task {
                try await forceUpdateExamInfo()
            }
        }
        if let data = userDefaults.data(forKey: "UstcUgAASScoreCache") {
            scoreJsonCache = try JSON(data: data)
        } else {
            Task {
                try await forceUpdateScoreInfo()
            }
        }
    }

    func saveToCalendar() throws {
        try Course.saveToCalendar(courses, name: semesterName, startDate: semesterDate)
    }

    func saveCache() throws {
        print("!!! Save UGAAS Called")
        let encoder = JSONEncoder()
        var data = try encoder.encode(lastUpdatedCurriculum)
        userDefaults.set(data, forKey: "UstcUgAASLastUpdatedCurriculum")
        data = try encoder.encode(lastUpdatedExams)
        userDefaults.set(data, forKey: "UstcUgAASLastUpdateExams")
        data = try encoder.encode(lastUpdatedScores)
        userDefaults.set(data, forKey: "UstcUgAASLastUpdateScores")
        data = try curriculumJsonCache.rawData()
        userDefaults.set(data, forKey: "UstcUgAASCurriculumCache")
        data = try JSONEncoder().encode(exams)
        userDefaults.set(data, forKey: "UstcUgAASExamCache")
        data = try scoreJsonCache.rawData()
        userDefaults.set(data, forKey: "UstcUgAASScoreCache")
    }

    func login() async throws {
        if try await !UstcCasClient.main.requireLogin() {
            return
        }

        let session = URLSession.shared
        // jw.ustc.edu.cn login.
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())
        let _ = try await session.data(for: request)
    }

    func getCurriculum() async throws -> [Course] {
        if lastUpdatedCurriculum == nil {
            try await forceUpdateCurriculum()
        }
        var result: [Course] = []
        for (_, subJson): (String, JSON) in curriculumJsonCache["studentTableVm"]["activities"] {
            var classPositionString = subJson["room"].stringValue
            if classPositionString == "" {
                classPositionString = subJson["customPlace"].stringValue
            }
            let tmp = Course(dayOfWeek: Int(subJson["weekday"].stringValue)!,
                             startTime: Int(subJson["startUnit"].stringValue)!,
                             endTime: Int(subJson["endUnit"].stringValue)!,
                             name: subJson["courseName"].stringValue,
                             classIDString: subJson["courseCode"].stringValue,
                             classPositionString: classPositionString,
                             classTeacherName: subJson["teachers"][0].stringValue,
                             weekString: subJson["weeksStr"].stringValue)

            result.append(tmp)
        }
        courses = Course.clean(result)
        return courses
    }

    func forceUpdateCurriculum() async throws {
        print("!!! Refresh UgAAS Curriculum")
        try await login()
        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!)
        let (_, response) = try await session.data(for: request)

        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }

        let (data, _) = try await session.data(for: URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(semesterID)/print-data/\(tableID)?weekIndex=")!))
        curriculumJsonCache = try JSON(data: data)
        lastUpdatedCurriculum = Date()
        try saveCache()
    }

    func getExamInfo() async throws -> [Exam] {
        if !(lastUpdatedExams != nil && lastUpdatedExams!.addingTimeInterval(7200) > Date()) {
            try await forceUpdateExamInfo()
        }
        return exams
    }

    func forceUpdateExamInfo() async throws {
        print("!!! Refresh UgAAS Exam Info")
        try await login()
        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/exam-arrange")!)
        let (data, _) = try await session.data(for: request)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        }

        let document: Document = try SwiftSoup.parse(dataString)
        let examsParsed: Elements = try document.select("#exams > tbody > tr")
        exams = []
        for examParsed: Element in examsParsed.array() {
            let textList: [String] = examParsed.children().array().map { $0.ownText() }
            exams.append(Exam(classIDString: textList[0], typeName: textList[1], className: textList[2], time: textList[3], classRoomName: textList[4], classRoomBuildingName: textList[5], classRoomDistrict: textList[6], description: textList[7]))
        }
        lastUpdatedExams = Date()
        try saveCache()
    }

    func getScore() async throws -> Score {
        if lastUpdatedScores == nil {
            try await forceUpdateScoreInfo()
        }
        var result = Score()
        let subJson = scoreJsonCache["stdGradeRank"]
        result.gpa = Double(subJson["gpa"].stringValue)!
        result.majorName = subJson["majorName"].stringValue
        result.majorRank = Int(subJson["majorRank"].stringValue)!
        result.majorStdCount = Int(subJson["majorStdCount"].stringValue)!

        var courseScoreList: [CourseScore] = []
        for (_, semesterJson): (String, JSON) in scoreJsonCache["semesters"] {
            for (_, courseScoreJson): (String, JSON) in semesterJson["scores"] {
                let tmp = CourseScore(courseName: courseScoreJson["courseNameCh"].stringValue,
                                      courseCode: courseScoreJson["courseCode"].stringValue,
                                      credit: Double(courseScoreJson["credits"].stringValue)!,
                                      gpa: Double(courseScoreJson["gp"].stringValue),
                                      lessonCode: courseScoreJson["lessonCode"].stringValue,
                                      score: courseScoreJson["score"].stringValue,
                                      semesterID: Int(courseScoreJson["semesterAssoc"].stringValue)!,
                                      semesterName: courseScoreJson["semesterCh"].stringValue)
                courseScoreList.append(tmp)
            }
        }
        result.courseScores = courseScoreList
        score = result
        return score
    }

    func forceUpdateScoreInfo() async throws {
        print("!!! Refresh UgAAS Score Info")
        try await login()
        let session = URLSession.shared
        let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?semesterIds")!)

        let (data, _) = try await session.data(for: request)
        scoreJsonCache = try JSON(data: data)
        lastUpdatedScores = Date()
        try saveCache()
    }

    init() {
        exceptionCall(loadCache)
    }
}
