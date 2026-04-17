//
//  USTCCatalogService.swift
//  Life@USTC
//
//  Typed service client for catalog.ustc.edu.cn (public course catalog).
//  Does NOT require authentication.
//

import Foundation
import os.log

private let logger = Logger(
    subsystem: "dev.tiankaima.Life-USTC",
    category: "USTCCatalogService"
)

/// Provides typed access to catalog.ustc.edu.cn public APIs.
struct USTCCatalogService {
    let session: URLSession
    let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://catalog.ustc.edu.cn")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - Semesters

    /// Fetch the list of all semesters.
    func fetchSemesters() async throws -> [CatalogSemesterDTO] {
        let url = baseURL.appendingPathComponent("api/teach/semester/list")
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let semesters = try decoder.decode([CatalogSemesterDTO].self, from: data)

        logger.debug("Fetched \(semesters.count) semesters from catalog")
        return semesters
    }

    // MARK: - Lessons

    /// Fetch lessons for a given semester.
    func fetchLessons(semesterId: Int) async throws -> [CatalogLessonDTO] {
        let url = baseURL.appendingPathComponent("api/teach/lesson/list-for-teach/\(semesterId)")
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let lessons = try decoder.decode([CatalogLessonDTO].self, from: data)

        logger.debug("Fetched \(lessons.count) lessons for semester \(semesterId)")
        return lessons
    }

    // MARK: - Exams

    /// Fetch exam list for a given semester.
    func fetchExams(semesterId: Int) async throws -> [CatalogExamDTO] {
        let url = baseURL.appendingPathComponent("api/teach/exam/list/\(semesterId)")
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let exams = try decoder.decode([CatalogExamDTO].self, from: data)

        logger.debug("Fetched \(exams.count) exams for semester \(semesterId)")
        return exams
    }
}
