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
    func refreshSemesterList() async throws -> [String: String]
    func refreshSemester(id: String) async throws -> Semester
}

extension CurriculumProtocol {
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

extension ManagedDataSource {
    var curriculum: any ManagedDataProtocol {
        ManagedUserDefaults(key: "curriculum", refreshFunc: Curriculum.sharedDelegate.refresh)
    }
}
