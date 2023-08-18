//
//  SharedDelegates.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import Foundation

extension Curriculum {
    static var sharedDelegate: any CurriculumProtocol {
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
