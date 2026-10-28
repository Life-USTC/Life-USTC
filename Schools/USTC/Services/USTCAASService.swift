//
//  USTCAASService.swift
//  Life@USTC
//
//  Typed service client for jw.ustc.edu.cn (Academic Affairs System).
//  Requires an authenticated URLSession (cookies set by CAS login).
//

import Foundation
import LifeClientCore

/// Provides typed access to jw.ustc.edu.cn APIs.
/// Establish the AAS session after CAS login before fetching authenticated data.
struct USTCAASService {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func establishSession() async throws -> Bool {
        _ = try await session.data(from: USTCCAS.aasSSOURL)
        _ = try await session.data(from: USTCCAS.aasCASLoginURL)
        let (_, response) = try await session.data(from: USTCCAS.aasRootURL)
        return response.url?.absoluteString == USTCCAS.aasHomeURL.absoluteString
    }

    // MARK: - Student ID

    /// Extract the student ID from the course-table redirect URL.
    func fetchStudentID() async throws -> String {
        let (_, response) = try await session.data(from: USTCCourseTable.pageURL)
        guard let finalURL = response.url else {
            throw USTCServiceError.parseError("Cannot extract student ID")
        }
        return try USTCCourseTable.studentID(from: finalURL)
    }

    // MARK: - Course Table

    /// Fetch lesson IDs for a given semester.
    func fetchLessonIDs(semesterID: String, studentID: String) async throws -> [Int] {
        guard let semester = Int(semesterID) else {
            throw USTCServiceError.parseError("Invalid semester ID")
        }
        let url = USTCCourseTable.dataURL(semesterID: semester, studentID: studentID)
        let (data, _) = try await session.data(from: url)
        return try USTCCourseTable.parse(data)
    }

    // MARK: - Exams

    /// Parse exam data from the HTML table at /for-std/exam-arrange.
    func fetchExams() async throws -> [USTCExamEntry] {
        let (data, _) = try await session.data(from: USTCAcademic.examURL)
        return try USTCAcademic.parseExams(data)
    }

    // MARK: - Scores

    func fetchScores(trainTypeId: Int = 1) async throws -> USTCScoreReport {
        let (data, _) = try await session.data(from: USTCAcademic.scoreURL(trainTypeID: trainTypeId))
        return try USTCAcademic.parseScores(data)
    }

    // MARK: - Schedule Table (POST)

    /// Fetch detailed schedule from ws/schedule-table/datum.
    func fetchScheduleTable(semesterID: String, studentID: String) async throws -> Data {
        let url = URL(string: "https://jw.ustc.edu.cn/ws/schedule-table/datum")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "bizTypeId=2&semesterId=\(semesterID)&dataId=\(studentID)".data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        return data
    }
}

// MARK: - Error

enum USTCServiceError: LocalizedError {
    case notAuthenticated
    case parseError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not logged in to USTC"
        case .parseError(let msg):
            return "Parse error: \(msg)"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
