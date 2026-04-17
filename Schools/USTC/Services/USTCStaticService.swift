//
//  USTCStaticService.swift
//  Life@USTC
//
//  Typed service client for static.life-ustc.tiankaima.dev
//  (pre-scraped curriculum data). Does NOT require authentication.
//

import Foundation
import os.log

private let logger = Logger(
    subsystem: "dev.tiankaima.Life-USTC",
    category: "USTCStaticService"
)

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
    func fetchSemesters() async throws -> [StaticSemesterDTO] {
        let url = baseURL.appendingPathComponent("curriculum/semesters.json")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([StaticSemesterDTO].self, from: data)
    }

    // MARK: - Course List

    /// Fetch course list for a semester (used for graduate course matching).
    func fetchCourseList(semesterId: String) async throws -> [StaticCourseListItemDTO] {
        let url = baseURL.appendingPathComponent("curriculum/\(semesterId)/courses.json")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([StaticCourseListItemDTO].self, from: data)
    }

    // MARK: - Course Detail

    /// Fetch full course detail including lectures.
    func fetchCourse(semesterId: String, courseId: Int) async throws -> StaticCourseDTO {
        let url = baseURL.appendingPathComponent("curriculum/\(semesterId)/\(courseId).json")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(StaticCourseDTO.self, from: data)
    }
}
