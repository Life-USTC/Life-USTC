//
//  USTCStaticService.swift
//  Life@USTC
//
//  Typed service client for static.life-ustc.tiankaima.dev
//  (pre-scraped curriculum data). Does NOT require authentication.
//

import Foundation
import LifeClientCore

private let logger = AppLogger.logger(for: "USTCStatic")

/// Provides typed access to the static curriculum data server.
struct USTCStaticService {
    let session: URLSession
    let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://static.life-ustc.tiankaima.dev")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - Semesters

    /// Fetch semester list.
    func fetchSemesters() async throws -> [USTCStaticSemester] {
        let data = try await fetchSemestersData()
        return try USTCStatic.parseSemesters(data)
    }

    func fetchSemestersData() async throws -> Data {
        let url = baseURL.appendingPathComponent(USTCStatic.semestersPath)
        let (data, _) = try await session.data(from: url)
        return data
    }

    // MARK: - Course List

    /// Fetch course list for a semester (used for graduate course matching).
    func fetchCourseList(semesterId: String) async throws -> [USTCStaticCourseListItem] {
        let data = try await fetchCourseListData(semesterId: semesterId)
        return try USTCStatic.parseCourseList(data)
    }

    /// Requires the graduate app login cookies to be established on the session.
    func fetchGraduateCourseIDs(semesterId: String) async throws -> [Int] {
        let (data, _) = try await session.data(from: USTCStatic.graduateAppCoursesURL)
        let courses = try USTCStatic.parseGraduateAppCourses(data)
        let courseListData = try await fetchCourseListData(semesterId: semesterId)
        return try courses.matchCourseIDs(in: courseListData)
    }

    private func fetchCourseListData(semesterId: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(USTCStatic.courseListPath(semesterID: semesterId))
        let (data, _) = try await session.data(from: url)
        return data
    }

    // MARK: - Course Detail

    /// Fetch full course detail including lectures.
    func fetchCourse(semesterId: String, courseId: Int) async throws -> USTCStaticCourse {
        let url = baseURL.appendingPathComponent(USTCStatic.coursePath(semesterID: semesterId, courseID: courseId))
        let (data, _) = try await session.data(from: url)
        return try USTCStatic.parseCourse(data)
    }
}
