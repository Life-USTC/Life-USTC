//
//  Curriculum.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation

struct Curriculum: Codable {
    var semesters: [Semester]
    var semesterIDList: [String]

    static let example = Curriculum(semesters: [.example],
                                    semesterIDList: [Semester.example.id])
}

protocol CurriculumProtocol {
    func refreshSemesterIDList() async throws -> [String]
    func refreshSemester(id: String) async throws -> Semester
}

extension CurriculumProtocol {
    /// Parrallel refresh the whole curriculum
    func refresh() async throws -> Curriculum {
        var result = Curriculum(semesters: [], semesterIDList: [])
        result.semesterIDList = try await refreshSemesterIDList()
        await withTaskGroup(of: Semester?.self) { group in
            for id in result.semesterIDList {
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
