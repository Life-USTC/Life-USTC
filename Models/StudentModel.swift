//
//  StudentModel.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Foundation

enum UserType: String {
    case undergraduate
    case graduate
    case teacher
    case parent
    case managment
}

let userTypeDescription: [UserType: String] = [.undergraduate: "Notice; Undergraduate AAS",
                                               .graduate: "Notice; Graduate AAS",
                                               .teacher: "Notice; Teacher AAS",
                                               .parent: "Notice(Without CAS)",
                                               .managment: "Notice; Create Notice"]
