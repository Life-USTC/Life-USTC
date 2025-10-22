//
//  CurriculumProtocols.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

/// Protocol for curriculum delegates that fetch semesters by ID
/// Usage: `class exampleDelegate: CurriculumProtocolA & CurriculumProtocol`
class CurriculumProtocolA<T>: ManagedRemoteUpdateProtocol<Curriculum> {
    /// Returns list of semester IDs
    /// - Returns: Array of semester identifiers
    func refreshSemesterList() async throws -> [T] {
        assert(true)
        return []
    }

    /// Fetches complete semester data by ID
    /// - Parameter id: Semester identifier
    /// - Returns: Complete semester with courses
    func refreshSemester(id: T) async throws -> Semester {
        assert(true)
        return .example
    }

    /// Parallel refresh of all semesters
    /// Fetches semester list, then all semester details concurrently
    /// - Returns: Complete curriculum with all semesters
    override func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let semesterList = try await refreshSemesterList()
        await withTaskGroup(of: Semester?.self) { group in
            for id in semesterList {
                group.addTask { try? await self.refreshSemester(id: id) }
            }

            for await child in group {
                if let child {
                    result.semesters.append(child)
                }
            }
        }

        result.semesters = result.semesters
            .filter { !$0.courses.isEmpty }
            .sorted { $0.startDate > $1.startDate }

        if result.semesters.isEmpty {
            throw BaseError.runtimeError("No courses found")
        }

        return result
    }
}

/// Protocol for curriculum delegates that fetch incomplete semester info first
/// Useful when semester startDate is provided in initial list but courses need separate fetch
class CurriculumProtocolB: ManagedRemoteUpdateProtocol<Curriculum> {
    /// Returns base semester info (dates, name) without courses
    /// - Returns: Array of incomplete semesters with metadata
    func refreshSemesterBase() async throws -> [Semester] {
        assert(true)
        return []
    }

    /// Fetches complete course data for a semester
    /// - Parameter inComplete: Semester with metadata but no courses
    /// - Returns: Complete semester with all courses
    func refreshSemester(inComplete: Semester) async throws -> Semester {
        assert(true)
        return .example
    }

    /// Parallel refresh of all semesters
    /// Fetches base semester list, then all course details concurrently
    /// - Returns: Complete curriculum with all semesters
    override func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let incompleteSemesters = try await refreshSemesterBase()
        await withTaskGroup(of: Semester?.self) { group in
            for semester in incompleteSemesters {
                group.addTask {
                    try? await self.refreshSemester(inComplete: semester)
                }
            }

            for await child in group {
                if let child {
                    result.semesters.append(child)
                }
            }
        }

        // Remove semesters with no courses
        result.semesters = result.semesters
            .filter { !$0.courses.isEmpty }
            .sorted { $0.startDate > $1.startDate }

        if result.semesters.isEmpty {
            throw BaseError.runtimeError("No courses found")
        }

        return result
    }
}
