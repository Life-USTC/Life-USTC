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

extension ManagedDataSource<Curriculum> {
    static let curriculum = ManagedDataSource(
        local: ManagedLocalStorage("Curriculum"),
        remote: SchoolExport.shared.curriculumDelegate
    )
}
