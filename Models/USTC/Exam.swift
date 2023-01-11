//
//  Exam.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import Foundation

struct Exam: Codable, Identifiable {
    var id = UUID()
    var classIDString: String
    var typeName: String
    var className: String
    var time: String
    var classRoomName: String
    var classRoomBuildingName: String
    var classRoomDistrict: String
    var description: String
}
