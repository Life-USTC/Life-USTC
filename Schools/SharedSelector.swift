//
//  SharedSelector.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import Foundation

extension Curriculum {
    static var sharedDelegate: any CurriculumDelegateProtocol {
        USTCExports.curriculumDelegate
    }
}

extension Exam {
    static var sharedDelegate: any ExamDelegateProtocol {
        USTCExports.examDelegate
    }
}

extension Score {
    static var sharedDelegate: any ScoreDelegateProtocol {
        USTCExports.scoreDelegate
    }
}

extension Curriculum {
    static var sharedSemesterList: [Int: String] {
        USTCExports.semesterIDList
    }
}
