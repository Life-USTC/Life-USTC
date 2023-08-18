//
//  USTC+ClassroomDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI
import SwiftyJSON

class UstcClassroomDelegate {
    static var shared = UstcClassroomDelegate()
    @AppStorage("ustcClassroomDate") var date: Date = .init()

    func refresh() async throws -> [String: [Lesson]] {
        if try await !LoginClients.ustcCatalog.requireLogin() {
            throw BaseError.runtimeError("UstcCatalog Not logined")
        }
        let validToken = LoginClients.ustcCatalog.wrappedValue.token

        var cache: [String: JSON] = [:]
        for building in UstcClassroomDelegate.allBuildings {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)

            let url = URL(string: "https://catalog.ustc.edu.cn/api/teach/timetable-public/\(building)/\(dateString)?access_token=\(validToken)")!
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            cache[building] = try JSON(data: data)
        }

        var result: [String: [Lesson]] = [:]
        for building in UstcClassroomDelegate.allBuildings {
            if let json = cache[building] {
                for (_, subJson) in json["timetable"]["lessons"] {
                    let tmp = Lesson(classroomName: subJson["classroomName"].stringValue,
                                     courseName: subJson["courseName"].stringValue,
                                     startTime: subJson["start"].stringValue,
                                     endTime: subJson["end"].stringValue,
                                     color: .blue)
                    if result.keys.contains(building) {
                        result[building]?.append(tmp)
                    } else {
                        result[building] = [tmp]
                    }
                }

                for (_, subJson) in json["timetable"]["tmpLessons"] {
                    let tmp = Lesson(classroomName: subJson["classroomName"].stringValue,
                                     courseName: subJson["courseName"].stringValue,
                                     startTime: subJson["start"].stringValue,
                                     endTime: subJson["end"].stringValue,
                                     color: .green)
                    if result.keys.contains(building) {
                        result[building]?.append(tmp)
                    } else {
                        result[building] = [tmp]
                    }
                }

                for (_, subJson) in json["timetable"]["exams"] {
                    let tmp = Lesson(classroomName: subJson["classroomName"].stringValue,
                                     courseName: subJson["lessons"][0]["nameZh"].stringValue,
                                     startTime: subJson["start"].stringValue,
                                     endTime: subJson["end"].stringValue,
                                     color: .red)
                    if result.keys.contains(building) {
                        result[building]?.append(tmp)
                    } else {
                        result[building] = [tmp]
                    }
                }
            }
        }
        return result
    }
}

extension UstcClassroomDelegate {
    static var allBuildings = ["1", "2", "3", "5", "17", "11", "12", "13", "14", "22"]
    static var buildingNames: [String: String] = ["1": "第一教学楼",
                                                  "2": "第二教学楼",
                                                  "3": "第三教学楼",
                                                  "5": "第五教学楼",
                                                  "17": "先研院未来中心",
                                                  "11": "高新校区图书教育中心A楼",
                                                  "12": "高新校区图书教育中心B楼",
                                                  "13": "高新校区图书教育中心C楼",
                                                  "14": "高新校区师生活动中心",
                                                  "22": "高新校区信智楼"]
    static var buildingRooms: [String: [String]] = parseRoomJson()

    static var buildingRoomJsonCache: JSON?
    static func parseRoomJson() -> [String: [String]] {
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
}

extension ManagedDataSource {
    static let classroom = ManagedLocalStorage(key: "ustc_classroom", refreshFunc: UstcClassroomDelegate.shared.refresh)
}
