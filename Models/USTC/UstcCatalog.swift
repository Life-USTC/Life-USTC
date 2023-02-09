//
//  UstcCatalog.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/15.
//

import SwiftUI
import SwiftyJSON

struct Lesson: Identifiable {
    var id: UUID {
        UUID(name: "\(classroomName):\(courseName),\(startTime)->\(endTime)", nameSpace: .oid)
    }

    var classroomName: String
    var courseName: String
    var startTime: String // hh:mm
    var endTime: String // hh:mm
    var color: Color?

    static func clean(_ lessons: [Lesson]) -> [Lesson] {
        var result = lessons
        for lesson in result {
            let tmp = result.filter { $0.classroomName == lesson.classroomName && $0.courseName == lesson.courseName }
            if tmp.count > 1 {
                let startTime = tmp.map(\.startTime).sorted(by: { timeToInt($0) < timeToInt($1) }).first ?? "0"
                let endTime = tmp.map(\.endTime).sorted(by: { timeToInt($0) < timeToInt($1) }).last ?? "0"

                result.removeAll(where: { $0.classroomName == lesson.classroomName && $0.courseName == lesson.courseName })
                result.append(Lesson(classroomName: lesson.classroomName, courseName: lesson.courseName, startTime: startTime, endTime: endTime))
            }
        }
        return result
    }
}

func timeToInt(_ time: String) -> Int {
    let tmp = time.split(separator: ":")
    if tmp.count < 2 {
        return 0
    }
    return Int(tmp[0])! * 60 + Int(tmp[1])!
}

class UstcCatalogClient {
    static var main = UstcCatalogClient()
    static var allBuildings = ["1", "2", "3", "5", "17", "11", "12", "13", "14", "22"]
    static var buildingNames: [String: String] = ["1": "第一教学楼", "2": "第二教学楼",
                                                  "3": "第三教学楼", "5": "第五教学楼",
                                                  "17": "先研院未来中心", "11": "高新校区图书教育中心A楼",
                                                  "12": "高新校区图书教育中心B楼", "13": "高新校区图书教育中心C楼",
                                                  "14": "高新校区师生活动中心", "22": "高新校区信智楼"]
    static var buildingRoomJsonCache: JSON?
    static var buildingRooms: [String: [String]] {
        if buildingRoomJsonCache == nil {
            if let path = Bundle.main.path(forResource: "UstcRooms", ofType: "json") {
                let data = try! Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                buildingRoomJsonCache = try! JSON(data: data)
            }
        }

        var result: [String: [String]] = [:]

        for (_, subJson) in buildingRoomJsonCache! {
            let building = subJson["buildingCode"].stringValue
            let room = subJson["code"].stringValue

            if result.keys.contains(building) {
                result[building]?.append(room)
            } else {
                result[building] = [room]
            }
        }
        return result
    }

    static func buildingName(with id: String) -> String {
        buildingNames.first(where: { $0.key == id })?.value ?? "Error"
    }

    var token = ""
    var lastUpdated: Date?

    func updateToken() async throws {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catalog.ustc.edu.cn/get_token")!)
        token = try JSON(data: data)["access_token"].stringValue
        lastUpdated = Date()
    }

    func validToken() async throws -> String {
        if lastUpdated != nil, lastUpdated! + DateComponents(second: 3600) > Date() {
            return token
        } else {
            try await updateToken()
            return token
        }
    }

    func queryClassrooms(building: String, date: Date = Date()) async throws -> [Lesson] {
        let validToken = try await validToken()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catalog.ustc.edu.cn/api/teach/timetable-public/\(building)/\(dateString)?access_token=\(validToken)")!)
        let json = try JSON(data: data)

        var result: [Lesson] = []

        for (_, subJson) in json["timetable"]["lessons"] {
            let tmp = Lesson(classroomName: subJson["classroomName"].stringValue,
                             courseName: subJson["courseName"].stringValue,
                             startTime: subJson["start"].stringValue,
                             endTime: subJson["end"].stringValue,
                             color: .blue)
            result.append(tmp)
        }

        for (_, subJson) in json["timetable"]["tmpLessons"] {
            let tmp = Lesson(classroomName: subJson["classroomName"].stringValue,
                             courseName: subJson["courseName"].stringValue,
                             startTime: subJson["start"].stringValue,
                             endTime: subJson["end"].stringValue,
                             color: .green)
            result.append(tmp)
        }

        return result
    }

    func queryAllClassrooms(date: Date = Date()) async throws -> [String: [Lesson]] {
        var result: [String: [Lesson]] = [:]
        for building in UstcCatalogClient.allBuildings {
            result[building] = try await queryClassrooms(building: building, date: date)
        }
        return result
    }
}
