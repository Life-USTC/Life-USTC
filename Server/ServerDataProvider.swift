import Foundation
import SwiftData

/// Stores complete server learning snapshots for the timetable and widgets.
@MainActor
enum ServerDataProvider {
    private static var curriculumRefresh = UUID()
    private static var examRefresh = UUID()

    /// Fetches once and replaces curriculum and exams together after every
    /// subscribed section has loaded successfully.
    static func refreshLearningData(
        client: ServerClient = .shared,
        context: ModelContext? = nil
    ) async throws {
        guard client.isAuthenticated else { return }
        let revision = client.sessionRevision
        let refresh = UUID()
        curriculumRefresh = refresh
        examRefresh = refresh
        let sections = try await fetchSubscribedSections(client: client)
        try Task.checkCancellation()
        guard revision == client.sessionRevision,
              refresh == curriculumRefresh, refresh == examRefresh else {
            throw CancellationError()
        }
        try writeSnapshot(context: context) { context in
            try replaceCurriculum(sections, in: context)
            try replaceExams(sections, in: context)
        }
    }

    static func updateCurriculum(
        client: ServerClient = .shared,
        context: ModelContext? = nil
    ) async throws {
        guard client.isAuthenticated else { return }
        let revision = client.sessionRevision
        let refresh = UUID()
        curriculumRefresh = refresh
        let sections = try await fetchSubscribedSections(client: client)
        try Task.checkCancellation()
        guard revision == client.sessionRevision, refresh == curriculumRefresh else {
            throw CancellationError()
        }

        try writeSnapshot(context: context) { try replaceCurriculum(sections, in: $0) }
    }

    static func updateExams(
        client: ServerClient = .shared,
        context: ModelContext? = nil
    ) async throws {
        guard client.isAuthenticated else { return }
        let revision = client.sessionRevision
        let refresh = UUID()
        examRefresh = refresh
        let sections = try await fetchSubscribedSections(client: client)
        try Task.checkCancellation()
        guard revision == client.sessionRevision, refresh == examRefresh else {
            throw CancellationError()
        }

        try writeSnapshot(context: context) { try replaceExams(sections, in: $0) }
    }

    /// Clears the learning cache when its owner or backend changes. Grades,
    /// Blackboard homework and feeds belong to separate data sources.
    static func clearCachedLearningData(context: ModelContext? = nil) throws {
        curriculumRefresh = UUID()
        examRefresh = UUID()
        try writeSnapshot(context: context) { context in
            try deleteCurriculum(context)
            for exam in try context.fetch(FetchDescriptor<Exam>()) { context.delete(exam) }
        }
    }

    private static func replaceCurriculum(_ sections: [ServerSectionDetail], in context: ModelContext) throws {
        try deleteCurriculum(context)
        guard !sections.isEmpty else { return }
        let curriculum = Curriculum()
        context.insert(curriculum)

        let bySemester = Dictionary(grouping: sections) { $0.semester?.id }
        for (_, semesterSections) in bySemester {
            let info = semesterSections.first?.semester
            let semester = Semester(
                jw_id: info.map { String($0.jwId ?? $0.id) } ?? "unknown",
                name: info?.nameCn ?? "Semester unavailable".localized,
                startDate: info?.startDate ?? .distantPast,
                endDate: info?.endDate ?? .distantFuture
            )
            context.insert(semester)
            semester.curriculum = curriculum

            for section in semesterSections {
                let courseName = section.course?.nameCn ?? section.code
                let teacherNames = section.teachers?.map(\.nameCn).joined(separator: ", ") ?? ""
                let course = Course(
                    jw_id: section.jwId,
                    name: courseName,
                    courseCode: section.course?.code ?? "",
                    lessonCode: section.code,
                    teacherName: teacherNames,
                    credit: section.credits ?? 0
                )
                context.insert(course)
                course.semester = semester

                for schedule in section.schedules ?? [] {
                    guard let lectureDate = meetingDate(schedule, semester: info) else { continue }
                    let start = schedule.startTime.components
                    let end = schedule.endTime.components
                    guard let startDate = shanghaiCalendar.date(
                        bySettingHour: start.hour, minute: start.minute, second: 0, of: lectureDate
                    ), let endDate = shanghaiCalendar.date(
                        bySettingHour: end.hour, minute: end.minute, second: 0, of: lectureDate
                    ) else { continue }

                    let lecture = Lecture(
                        startDate: startDate, endDate: endDate,
                        name: courseName, location: schedule.customPlace ?? "",
                        teacherName: teacherNames, periods: schedule.periods ?? 0,
                        startIndex: schedule.startUnit, endIndex: schedule.endUnit
                    )
                    context.insert(lecture)
                    lecture.course = course
                }
            }
        }
    }

    private static func replaceExams(_ sections: [ServerSectionDetail], in context: ModelContext) throws {
        for exam in try context.fetch(FetchDescriptor<Exam>()) { context.delete(exam) }
        for section in sections {
            for entry in section.exams ?? [] {
                // Undated exams cannot be represented as an instant in the
                // local calendar cache; do not invent a date for them.
                guard let dateString = entry.examDate, let examDate = parseDate(dateString) else { continue }
                let start = entry.startTime ?? 0
                let end = entry.endTime ?? 0
                guard let startDate = shanghaiCalendar.date(
                    bySettingHour: start / 100, minute: start % 100, second: 0, of: examDate
                ), let endDate = shanghaiCalendar.date(
                    bySettingHour: end / 100, minute: end % 100, second: 0, of: examDate
                ) else { continue }

                context.insert(Exam(
                    lessonCode: section.code,
                    courseName: section.course?.nameCn ?? section.code,
                    typeName: entry.examBatch?.nameCn ?? "",
                    startDate: startDate, endDate: endDate,
                    classRoomName: entry.examRooms?.compactMap(\.room).joined(separator: ", ") ?? "",
                    classRoomBuildingName: "", classRoomDistrict: "",
                    description: entry.examMode ?? ""
                ))
            }
        }
    }

    private static func fetchSubscribedSections(client: ServerClient) async throws -> [ServerSectionDetail] {
        try Task.checkCancellation()
        let response: CalendarSubscriptionResponse = try await client.request(.getSubscriptions)
        var details: [ServerSectionDetail] = []
        for section in response.subscription?.sections ?? [] {
            try Task.checkCancellation()
            details.append(try await client.fetchSectionDetail(jwId: String(section.jwId)))
        }
        return details
    }

    private static func writeSnapshot(
        context: ModelContext?,
        _ update: (ModelContext) throws -> Void
    ) throws {
        // Use a dedicated context so rollback never discards an unrelated edit
        // waiting to autosave in the app's main context. Tests inject their own.
        // The displayed container may switch to demo while a request is in
        // flight. Server snapshots and ownership cleanup always target live data.
        let writer = context ?? ModelContext(SwiftDataStack.container(forDemo: false))
        do {
            try writer.transaction { try update(writer) }
        } catch {
            writer.rollback()
            throw error
        }
    }

    private static func deleteCurriculum(_ context: ModelContext) throws {
        for lecture in try context.fetch(FetchDescriptor<Lecture>()) { context.delete(lecture) }
        for course in try context.fetch(FetchDescriptor<Course>()) { context.delete(course) }
        for semester in try context.fetch(FetchDescriptor<Semester>()) { context.delete(semester) }
        for curriculum in try context.fetch(FetchDescriptor<Curriculum>()) { context.delete(curriculum) }
    }

    private static var shanghaiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private static func meetingDate(_ schedule: ServerScheduleRef, semester: ServerSemester?) -> Date? {
        if let date = schedule.date { return parseDate(date) }
        guard let start = semester?.startDate,
              let weekIndex = schedule.weekIndex, weekIndex >= 1 else { return nil }
        let calendar = shanghaiCalendar
        let startDay = calendar.startOfDay(for: start)
        let weekday = calendar.component(.weekday, from: startDay)
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday
        let dayOffset = mondayOffset + (weekIndex - 1) * 7 + schedule.weekday - 1
        guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDay),
              date >= startDay,
              semester?.endDate.map({ date <= calendar.startOfDay(for: $0) }) ?? true
        else { return nil }
        return date
    }

    private static func parseDate(_ value: String) -> Date? {
        if value.count == 10 {
            let formatter = DateFormatter()
            formatter.calendar = shanghaiCalendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = shanghaiCalendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.isLenient = false
            return formatter.date(from: value)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
