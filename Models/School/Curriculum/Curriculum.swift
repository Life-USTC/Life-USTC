//
//  Curriculum.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation

struct Curriculum: Codable, Equatable, ExampleDataProtocol {
    var semesters: [Semester]

    static let example = Curriculum(semesters: [.example])
}

typealias CurriculumProtocol = ManagedRemoteUpdateProtocol<Curriculum>

/// Usage: `class exampleDelegaet: CurriculumProtocolA & CurriculumProtocol`
protocol CurriculumProtocolA {
    func refreshSemesterList() async throws -> [String]
    func refreshSemester(id: String) async throws -> Semester
}

extension CurriculumProtocolA {
    /// Parrallel refresh the whole curriculum
    func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [])
        let semesterList = try await refreshSemesterList()
        await withTaskGroup(of: Semester?.self) { group in
            for id in semesterList {
                group.addTask {
                    try? await self.refreshSemester(id: id)
                }
            }

            for await child in group {
                if let child {
                    result.semesters.append(child)
                }
            }
        }
        return result
    }
}

/// - Note: Useful when semester startDate is not provided in `refreshSemesterList`
protocol CurriculumProtocolB {
    /// Return more info than just id and name, like start date and end date, but have empty courses
    func refreshSemesterBase() async throws -> [Semester]
    func refreshSemester(inComplete: Semester) async throws -> Semester
}

extension CurriculumProtocolB {
    /// Parrallel refresh the whole curriculum
    func refresh() async throws -> Curriculum {
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
        result.semesters = result.semesters.filter {
            !$0.courses.isEmpty
        }.sorted {
            $0.startDate > $1.startDate
        }

        return result
    }
}

extension ManagedDataSource<Curriculum> {
    static let curriculum = ManagedDataSource(
        local: ManagedLocalStorage("Curriculum"),
        remote: Curriculum.sharedDelegate
    )
}
