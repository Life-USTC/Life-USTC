//
//  Curriculum.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/17.
//

import Foundation
import SwiftData

@Model
final class Curriculum {
    var studentID: Int

    init(studentID: Int) {
        self.studentID = studentID
    }
}
