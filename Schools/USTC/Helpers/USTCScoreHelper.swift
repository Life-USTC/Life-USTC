//
//  USTCScoreDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import Foundation
import SwiftData

extension USTCSchool {
    @MainActor
    static func updateScore() async throws {
        if SwiftDataStack.isPresentingDemo { return }

        @LoginClient(.ustcAAS) var ustcAASClient: USTCAASClient

        if try await !_ustcAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        let report = try await USTCAASService().fetchScores()

        // Upsert ScoreSheet entity
        let gpa = report.gpa ?? 0
        let majorName = report.majorName ?? "Error"
        let majorRank = report.majorRank ?? 0
        let majorStdCount = report.majorStdCount ?? 0

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
        let entriesData = report.entries

        for entryData in entriesData {
            let lessonCode = entryData.lessonCode
            let entry = try SwiftDataStack.modelContext.upsert(
                predicate: #Predicate<ScoreEntry> { $0.lessonCode == lessonCode },
                update: { existing in
                    existing.courseName = entryData.courseName
                    existing.courseCode = entryData.courseCode
                    existing.semesterID = entryData.semesterID
                    existing.semesterName = entryData.semesterName
                    existing.credit = entryData.credits
                    existing.gpa = entryData.gradePoint
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
                        credit: entryData.credits,
                        gpa: entryData.gradePoint,
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
