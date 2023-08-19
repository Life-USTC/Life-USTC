//
//  Curriculum.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation

struct Curriculum: Codable {
    var semesters: [Semester]
    var semesterList: [String: String]

    static let example = Curriculum(semesters: [.example], semesterList: [Semester.example.id: Semester.example.name])
}

protocol CurriculumProtocol {
    func refresh() async throws -> Curriculum
}

/// Usage: `class exampleDelegaet: CurriculumProtocolA & CurriculumProtocol`
protocol CurriculumProtocolA {
    func refreshSemesterList() async throws -> [String: String]
    func refreshSemester(id: String) async throws -> Semester
}

extension CurriculumProtocolA {
    /// Parrallel refresh the whole curriculum
    func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [], semesterList: [:])
        result.semesterList = try await refreshSemesterList()
        await withTaskGroup(of: Semester?.self) { group in
            for id in result.semesterList.keys {
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
        var result = Curriculum(semesters: [], semesterList: [:])
        let incompleteSemesters = try await refreshSemesterBase()
        result.semesterList = incompleteSemesters.reduce(into: [:]) { $0[$1.id] = $1.name }
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
        return result
    }
}

extension ManagedDataSource {
    var curriculum: any ManagedDataProtocol {
        ManagedUserDefaults(key: "curriculum", refreshFunc: Curriculum.sharedDelegate.refresh)
    }
}
