//
//  UstcUgAAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/16.
//

import SwiftSoup
import SwiftUI
import SwiftyJSON
import WidgetKit

/// USTC Undergraduate Academic Affairs System
class UstcUgAASClient {
    static var main = UstcUgAASClient()
    private var semesterID: String = userDefaults.string(forKey: "semesterID") ?? "301"

    var curriculumDelegate = CurriculumDelegate()
    var examDelegate = ExamDelegate()
    var scoreDelegate = ScoreDelegate()

    func login() async throws {
        if try await !UstcCasClient.main.requireLogin() {
            return
        }

        // jw.ustc.edu.cn login.
        let _ = try await URLSession.shared.data(from: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())
    }
}

extension UstcUgAASClient {
    // TODO: Maintain a list of these values online, use cached to store them on device
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

    func selectSemester(id: String) {
        semesterID = id
    }

    func getSemesterID() -> String {
        semesterID
    }

    var semesterName: String {
        UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })!.key
    }

    var semesterStartDate: Date {
        UstcUgAASClient.semesterDateList.first(where: { $0.key == semesterName })!.value
    }
}
