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

    static let example: Exam = .init(classIDString: "MATH10001.01",
                                     typeName: "期末考试",
                                     className: "数学分析B1",
                                     time: "2023-02-28 14:30~16:30",
                                     classRoomName: "5401",
                                     classRoomBuildingName: "第五教学楼",
                                     classRoomDistrict: "东区",
                                     description: "")

    func parseTime() -> (time: Date, description: String) {
        let dateString = String(time.prefix(10))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let result = dateFormatter.date(from: dateString) ?? Date()
        return (result.stripTime(), String(time.suffix(11)))
    }

    func daysLeft() -> Int {
        Calendar.current.dateComponents([.day], from: Date().stripTime(), to: parseTime().time).day ?? 0
    }
}
