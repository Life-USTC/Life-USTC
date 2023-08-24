//
//  UserType.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

/// Identify user's role in the app, mainly used to construct View accrodingly.
enum UserType: String, CaseIterable {
    case undergraduate
    #if DEBUG
    case graduate
    case teacher
    case parent
    case managment
    #endif

    static var main = UserType.undergraduate

    var caption: String {
        switch self {
        case .undergraduate: return "Notice; Undergraduate AAS" #if DEBUG
        case .graduate: return "Notice; Graduate AAS"
        case .teacher: return "Notice; Teacher AAS"
        case .parent: return "Notice(Without CAS)"
        case .managment: return "Notice; Create Notice"
        #endif
        }
    }
}
