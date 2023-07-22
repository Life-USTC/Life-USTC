//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import EventKit
import SwiftSoup
import SwiftUI
import WidgetKit

struct Exam: Codable, Identifiable, Equatable {
    var id: String {
        lessonCode
    }

    // MARK: - Information about the course

    /// Code to indicate which exact lesson the student is tanking, like MATH1000.01
    ///
    /// - Description:
    /// Make sure this is indentical on Score & Course.
    var lessonCode: String

    /// - Important:
    /// You are supposed to localize this
    var courseName: String

    // MARK: - Information about the exam

    /// Brief information about the exam
    ///
    /// - Important:
    /// Shown on UI, please set a length limit
    ///
    /// - Description:
    /// ## Localizations:
    /// ## Localizations
    /// Some notations are localized, such as 期末考试 <=> Final, 期中考试 <=> Mid-term, 小测 <=> Quiz
    /// Meaning that you don't have to localization on your own
    /// Try convert to this standard, or file issue on GitHub.
    var typeName: String

    /// Unparsed time, format: YYYY-MM-DD hh:mm~hh:mm (start~end)
    ///  - Important:
    ///  This means seconds are ignored, I don't know whether anyone should care this, but...
    ///  Also timezone-wise, this wouldn't store ANY timezone information, it's all going to be based on user's settings.
    var rawTime: String

    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var description: String

    init(lessonCode: String,
         typeName: String,
         courseName: String,
         rawTime: String,
         classRoomName: String,
         classRoomBuildingName: String,
         classRoomDistrict: String = "",
         description: String = "")
    {
        self.lessonCode = lessonCode
        self.typeName = typeName
        self.courseName = courseName
        self.rawTime = rawTime
        self.classRoomName = classRoomName
        self.classRoomBuildingName = classRoomBuildingName
        self.classRoomDistrict = classRoomDistrict
        self.description = description
    }
}

protocol ExamDelegateProtocol: ObservableObject, UserDefaultsADD & LastUpdateADD & NotifyUserWhenUpdateADD where D.Type == [Exam].Type {}

extension ExamDelegateProtocol {
    var nameToShowWhenUpdate: String {
        "Exam"
    }

    func afterForceUpdate() async throws {
        lastUpdate = Date()
        try saveCache()
        let data = Exam.merge(data, with: try await parseCache())

        if self.data != data {
            InAppNotificationDelegate.shared.addInfoMessage(String(format: "%@ have update".localized,
                                                                   nameToShowWhenUpdate.localized))
        }
        foregroundUpdateData(with: data)
    }
}
