//
//  USTCScoreDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftData
import SwiftyJSON

extension USTCSchool {
    @MainActor
    static func updateScore() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        @LoginClient(.ustcAAS) var ustcAASClient: USTCAASClient

        let scoreURL = URL(
            string:
                "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?trainTypeId=1&semesterIds"
        )!
        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let (data, _) = try await URLSession.shared.data(from: scoreURL)
        let cache = try JSON(data: data)

        // Upsert ScoreSheet entity
        let subJson = cache["stdGradeRank"]
        let gpa = cache["overview"]["gpa"].double ?? 0
        let majorName = subJson["majorName"].string ?? "Error"
        let majorRank = subJson["majorRank"].int ?? 0
        let majorStdCount = subJson["majorStdCount"].int ?? 0

        let scoreSheet = try SwiftDataStack.modelContext.upsert(
            predicate: #Predicate<ScoreSheet> { $0.uniqueID == 0 },
            update: { existing in
                existing.gpa = gpa
                existing.majorName = majorName
                existing.majorRank = majorRank
                existing.majorStdCount = majorStdCount

                // Remove old entries
                for entry in existing.entries {
                    SwiftDataStack.modelContext.delete(entry)
                }
                existing.entries = []
            },
            create: {
                ScoreSheet(
                    gpa: gpa,
                    majorRank: majorRank,
                    majorStdCount: majorStdCount,
                    majorName: majorName
                )
            }
        )

        // Process and insert score entries
        let entriesData = cache["semesters"]
            .flatMap { _, semesterJSON in
                semesterJSON["scores"]
                    .map { _, courseJSON in
                        (
                            courseName: courseJSON["courseNameCh"].stringValue,
                            courseCode: courseJSON["courseCode"].stringValue,
                            lessonCode: courseJSON["lessonCode"].stringValue,
                            semesterID: courseJSON["semesterAssoc"].stringValue,
                            semesterName: courseJSON["semesterCh"].stringValue,
                            credit: Double(courseJSON["credits"].stringValue) ?? 0,
                            gpa: Double(courseJSON["gp"].stringValue),
                            score: courseJSON["scoreCh"].stringValue
                        )
                    }
            }

        for entryData in entriesData {
            let lessonCode = entryData.lessonCode
            let entry = try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<ScoreEntry> { $0.lessonCode == lessonCode },
                update: { existing in
                    existing.courseName = entryData.courseName
                    existing.courseCode = entryData.courseCode
                    existing.semesterID = entryData.semesterID
                    existing.semesterName = entryData.semesterName
                    existing.credit = entryData.credit
                    existing.gpa = entryData.gpa
                    existing.score = entryData.score
                    existing.scoreSheet = scoreSheet
                },
                create: {
                    ScoreEntry(
                        courseName: entryData.courseName,
                        courseCode: entryData.courseCode,
                        lessonCode: entryData.lessonCode,
                        semesterID: entryData.semesterID,
                        semesterName: entryData.semesterName,
                        credit: entryData.credit,
                        gpa: entryData.gpa,
                        score: entryData.score
                    )
                }
            )

            entry.scoreSheet = scoreSheet
            scoreSheet.entries.append(entry)
        }

        try SwiftDataStack.modelContext.save()
    }
}
