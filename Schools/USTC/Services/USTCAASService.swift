//
//  USTCAASService.swift
//  Life@USTC
//
//  Typed service client for jw.ustc.edu.cn (Academic Affairs System).
//  Requires an authenticated URLSession (cookies set by CAS login).
//

import Foundation
import SwiftSoup

private let logger = AppLogger.logger(for: "USTCAAS")

/// Provides typed access to jw.ustc.edu.cn APIs.
/// Requires that CAS → AAS login has been performed on the shared URLSession.
struct USTCAASService {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Student ID

    /// Extract the student ID from the course-table redirect URL.
    func fetchStudentID() async throws -> String {
        let url = URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!
        let (_, response) = try await session.data(from: url)

        guard let finalURL = response.url?.absoluteString,
              let match = finalURL.firstMatch(of: /(\d+)/)
        else {
            logger.error("Failed to extract student ID from redirect")
            throw USTCServiceError.parseError("Cannot extract student ID")
        }

        let studentID = String(match.1)
        logger.debug("Got student ID: \(studentID)")
        return studentID
    }

    // MARK: - Course Table

    /// Fetch lesson IDs for a given semester.
    func fetchLessonIDs(semesterID: String, studentID: String) async throws -> [Int] {
        let url = URL(
            string: "https://jw.ustc.edu.cn/for-std/course-table/get-data?bizTypeId=2&semesterId=\(semesterID)&dataId=\(studentID)"
        )!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(AASCourseTableDTO.self, from: data)

        let ids = response.lessonIds ?? []
        logger.debug("Fetched \(ids.count) lesson IDs for semester \(semesterID)")
        return ids
    }

    // MARK: - Exams

    /// Parse exam data from the HTML table at /for-std/exam-arrange.
    func fetchExams() async throws -> [AASExamDTO] {
        let url = URL(string: "https://jw.ustc.edu.cn/for-std/exam-arrange")!
        let (data, _) = try await session.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            throw USTCServiceError.parseError("Cannot decode exam HTML")
        }

        let document = try SwiftSoup.parse(html)
        let rows = try document.select("#exams > tbody > tr")

        var exams: [AASExamDTO] = []
        for row in rows.array() {
            let cols = row.children().array().map { $0.ownText() }
            guard cols.count >= 8 else { continue }

            exams.append(AASExamDTO(
                lessonCode: cols[0],
                typeName: cols[1],
                courseName: cols[2],
                dateTimeString: cols[3],
                classRoomName: cols[4],
                classRoomBuildingName: cols[5],
                classRoomDistrict: cols[6],
                detail: cols[7]
            ))
        }

        logger.debug("Parsed \(exams.count) exams from HTML")
        return exams
    }

    // MARK: - Scores

    /// Fetch grade list as JSON.
    func fetchScores(trainTypeId: Int = 1) async throws -> Data {
        let url = URL(
            string: "https://jw.ustc.edu.cn/for-std/grade/sheet/getGradeList?trainTypeId=\(trainTypeId)&semesterIds"
        )!
        let (data, _) = try await session.data(from: url)

        logger.debug("Fetched score data (\(data.count) bytes)")
        return data
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
