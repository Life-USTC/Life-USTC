//
//  ServerDataProvider.swift
//  Life@USTC
//
//  Fetches user-subscribed curriculum, exams, and semesters from the server
//  and maps them into the app's SwiftData models (Course, Lecture, Exam, Semester).
//

import Foundation
import SwiftData
import SwiftUI

private let logger = AppLogger.logger(for: "ServerDataProvider")

/// Bridges server API responses into local SwiftData models.
enum ServerDataProvider {

    // MARK: - Public Entry Points

    /// Fetch subscribed sections from server and populate Courses + Lectures.
    /// Replaces all server-sourced curriculum data (snapshot-based refresh).
    @MainActor
    static func updateCurriculum() async throws {
        let client = ServerClient.shared
        guard client.isAuthenticated else {
            logger.info("Skipping server curriculum update — not authenticated")
            return
        }

        logger.info("Fetching subscriptions from server…")

        // 1. Get user's subscribed section IDs
        let subResponse: CalendarSubscriptionResponse = try await client.request(.getSubscriptions)
        guard let sections = subResponse.subscription?.sections, !sections.isEmpty else {
            logger.info("No subscribed sections found on server")
            return
        }

        logger.info("Found \(sections.count) subscribed sections")

        // 2. Fetch full detail (with schedules + exams) for each section
        var sectionDetails: [ServerSectionDetail] = []
        for section in sections {
            do {
                let detail: ServerSectionDetail = try await client.request(.getSection(jwId: String(section.jwId)))
                sectionDetails.append(detail)
            } catch {
                logger.warning("Failed to fetch section detail for jwId=\(section.jwId): \(error)")
            }
        }

        logger.info("Fetched \(sectionDetails.count) section details, mapping to SwiftData…")

        // 3. Map to SwiftData
        try mapSectionsToSwiftData(sectionDetails)

        logger.info("Server curriculum update complete")
    }

    /// Fetch exams for subscribed sections from server.
    @MainActor
    static func updateExams() async throws {
        let client = ServerClient.shared
        guard client.isAuthenticated else {
            logger.info("Skipping server exam update — not authenticated")
            return
        }

        // Get subscribed section IDs, then fetch detail for each to get exams
        let subResponse: CalendarSubscriptionResponse = try await client.request(.getSubscriptions)
        guard let sections = subResponse.subscription?.sections, !sections.isEmpty else {
            return
        }

        var allExams: [(exam: ServerExamEntry, courseName: String, sectionCode: String)] = []

        for section in sections {
            do {
                let detail: ServerSectionDetail = try await client.request(.getSection(jwId: String(section.jwId)))
                if let exams = detail.exams {
                    let courseName = detail.course?.nameCn ?? "Unknown"
                    let sectionCode = detail.code
                    for exam in exams {
                        allExams.append((exam, courseName, sectionCode))
                    }
                }
            } catch {
                logger.warning("Failed to fetch section exams for jwId=\(section.jwId): \(error)")
            }
        }

        logger.info("Found \(allExams.count) exams from server, mapping…")
        try mapExamsToSwiftData(allExams)
    }

    // MARK: - SwiftData Mapping

    @MainActor
    private static func mapSectionsToSwiftData(_ details: [ServerSectionDetail]) throws {
        let context = SwiftDataStack.modelContext

        // Ensure curriculum root exists
        let curriculum = try context.upsert(
            predicate: #Predicate<Curriculum> { $0.uniqueID == 0 },
            update: { _ in },
            create: { Curriculum() }
        )
        try context.save()

        // Group sections by semester
        let bySemester = Dictionary(grouping: details) { $0.semester?.id ?? 0 }

        for (_, semesterSections) in bySemester {
            guard let serverSem = semesterSections.first?.semester else { continue }

            // Upsert semester
            let semJwId = String(serverSem.jwId ?? serverSem.id)
            let semester = try context.upsert(
                predicate: #Predicate<Semester> { $0.jw_id == semJwId },
                update: { existing in
                    existing.name = serverSem.nameCn
                    if let sd = serverSem.startDate { existing.startDate = sd }
                    if let ed = serverSem.endDate { existing.endDate = ed }
                },
                create: {
                    Semester(
                        jw_id: semJwId,
                        name: serverSem.nameCn,
                        startDate: serverSem.startDate ?? .distantPast,
                        endDate: serverSem.endDate ?? .distantFuture
                    )
                }
            )
            semester.curriculum = curriculum

            // Upsert each section → Course + Lectures
            for detail in semesterSections {
                let courseJwId = detail.course?.jwId ?? detail.jwId
                let courseName = detail.course?.nameCn ?? detail.code
                let teacherNames = detail.teachers?.map(\.nameCn).joined(separator: ", ") ?? ""
                let credits = detail.credits ?? 0

                let course = try context.upsert(
                    predicate: #Predicate<Course> { $0.jw_id == courseJwId },
                    update: { existing in
                        existing.name = courseName
                        existing.courseCode = detail.course?.code ?? ""
                        existing.lessonCode = detail.code
                        existing.teacherName = teacherNames
                        existing.credit = credits
                        existing.semester = semester
                        // Delete old lectures
                        for lecture in existing.lectures {
                            context.delete(lecture)
                        }
                        existing.lectures = []
                    },
                    create: {
                        let c = Course(
                            jw_id: courseJwId,
                            name: courseName,
                            courseCode: detail.course?.code ?? "",
                            lessonCode: detail.code,
                            teacherName: teacherNames,
                            credit: credits
                        )
                        c.semester = semester
                        return c
                    }
                )

                // Expand schedules into concrete Lecture instances
                if let schedules = detail.schedules {
                    let lectures = expandSchedules(
                        schedules,
                        semesterStart: semester.startDate,
                        semesterEnd: semester.endDate,
                        courseName: courseName,
                        teacherName: teacherNames
                    )
                    for lecture in lectures {
                        context.insert(lecture)
                        lecture.course = course
                        course.lectures.append(lecture)
                    }
                }
            }

            try context.save()
        }

        logger.info("Mapped \(details.count) sections to SwiftData courses")
    }

    @MainActor
    private static func mapExamsToSwiftData(
        _ entries: [(exam: ServerExamEntry, courseName: String, sectionCode: String)]
    ) throws {
        let context = SwiftDataStack.modelContext

        // Delete all existing exams, then reinsert from server (snapshot refresh)
        let existingExams = try context.fetch(FetchDescriptor<Exam>())
        for exam in existingExams {
            context.delete(exam)
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for entry in entries {
            let serverExam = entry.exam

            // Parse exam date
            guard let dateStr = serverExam.examDate,
                  let examDate = parseDate(dateStr)
            else { continue }

            // Parse start/end time
            let (startH, startM) = serverExam.startTime.map { ($0 / 100, $0 % 100) } ?? (0, 0)
            let (endH, endM) = serverExam.endTime.map { ($0 / 100, $0 % 100) } ?? (0, 0)

            var cal = Calendar.current
            cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!

            let startDate = cal.date(bySettingHour: startH, minute: startM, second: 0, of: examDate) ?? examDate
            let endDate = cal.date(bySettingHour: endH, minute: endM, second: 0, of: examDate) ?? examDate

            // Room info
            let roomNames = serverExam.examRooms?.compactMap(\.room).joined(separator: ", ") ?? ""
            let batchName = serverExam.examBatch?.nameCn ?? ""

            let exam = Exam(
                lessonCode: entry.sectionCode,
                courseName: entry.courseName,
                typeName: batchName,
                startDate: startDate,
                endDate: endDate,
                classRoomName: roomNames,
                classRoomBuildingName: "",
                classRoomDistrict: "",
                description: serverExam.examMode ?? ""
            )

            context.insert(exam)
        }

        try context.save()
        logger.info("Mapped \(entries.count) exams from server")
    }

    // MARK: - Schedule Expansion

    /// Expand weekly schedule patterns into concrete Lecture dates within the semester.
    private static func expandSchedules(
        _ schedules: [ServerScheduleRef],
        semesterStart: Date,
        semesterEnd: Date,
        courseName: String,
        teacherName: String
    ) -> [Lecture] {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        // Semester start should be a Monday (week 1 day 1)
        let startWeekday = cal.component(.weekday, from: semesterStart)
        // Swift Calendar: 1=Sunday, 2=Monday … 7=Saturday
        let mondayOffset = (startWeekday == 1) ? -6 : (2 - startWeekday)
        let semesterMonday = cal.date(byAdding: .day, value: mondayOffset, to: semesterStart)!

        var lectures: [Lecture] = []

        for schedule in schedules {
            // weekIndex is 1-based, weekday is 1=Monday … 7=Sunday (USTC convention)
            guard let weekIndex = schedule.weekIndex, weekIndex >= 1 else { continue }

            let dayOffset = (weekIndex - 1) * 7 + (schedule.weekday - 1)
            guard let lectureDate = cal.date(byAdding: .day, value: dayOffset, to: semesterMonday) else { continue }

            // Skip if outside semester bounds
            if lectureDate < semesterStart || lectureDate > semesterEnd { continue }

            let startComponents = schedule.startTime.components
            let endComponents = schedule.endTime.components

            let startDate = cal.date(
                bySettingHour: startComponents.hour,
                minute: startComponents.minute,
                second: 0,
                of: lectureDate
            ) ?? lectureDate

            let endDate = cal.date(
                bySettingHour: endComponents.hour,
                minute: endComponents.minute,
                second: 0,
                of: lectureDate
            ) ?? lectureDate

            let lecture = Lecture(
                startDate: startDate,
                endDate: endDate,
                name: courseName,
                location: schedule.customPlace ?? "",
                teacherName: teacherName,
                periods: Double(schedule.periods ?? 0),
                startIndex: schedule.startUnit,
                endIndex: schedule.endUnit
            )

            lectures.append(lecture)
        }

        return lectures
    }

    // MARK: - Date Parsing

    private static func parseDate(_ string: String) -> Date? {
        // Try ISO 8601 first, then yyyy-MM-dd
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        if let date = iso.date(from: string) { return date }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return df.date(from: string)
    }
}
