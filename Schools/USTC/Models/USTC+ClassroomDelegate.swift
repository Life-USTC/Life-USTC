//
//  USTC+ClassroomDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI
import SwiftyJSON

struct Lesson: Identifiable, Equatable {
    var id: UUID {
        UUID(name: "\(classroomName):\(courseName),\(startTime)->\(endTime)", nameSpace: .oid)
    }

    var classroomName: String
    var courseName: String
    var startTime: String // hh:mm
    var endTime: String // hh:mm
    var color: Color

    func overlapping(_ other: Lesson) -> Bool {
        if classroomName != other.classroomName {
            return false
        }
        if timeToInt(other.endTime) <= timeToInt(startTime) || timeToInt(endTime) <= timeToInt(other.startTime) {
            return false
        }
        return true
    }

    func containedIn(_ other: Lesson) -> Bool {
        if classroomName != other.classroomName {
            return false
        }
        if timeToInt(startTime) < timeToInt(other.startTime) {
            return false
        }
        if timeToInt(endTime) > timeToInt(other.endTime) {
            return false
        }
        return true
    }

    static func clean(_ lessons: [Lesson]) -> [Lesson] {
        // cleaning rules:
        // 1. same classroom and course name, results start time is the earliest start time, end time is the latest end time, color is the same
        // 2. same classroom and different course name: (time overlap)
        // 2.2. if two are not contained in each other, keep both, change course name to "course1, course2", start time is the earliest start time, end time is the latest end time, color is set to YELLOW
        // 2.1. if one is contained in the other, remove the contained one
        var result = lessons
        for lesson in result {
            let tmp = result.filter { $0.classroomName == lesson.classroomName && $0.courseName == lesson.courseName }
            if tmp.count > 1 {
                let startTime = tmp.map(\.startTime).sorted(by: { timeToInt($0) < timeToInt($1) }).first ?? "0"
                let endTime = tmp.map(\.endTime).sorted(by: { timeToInt($0) < timeToInt($1) }).last ?? "0"

                result.removeAll(where: { $0.classroomName == lesson.classroomName && $0.courseName == lesson.courseName })
                result.append(Lesson(classroomName: lesson.classroomName, courseName: lesson.courseName, startTime: startTime, endTime: endTime, color: lesson.color))
            }
        }

        for lesson in result {
            let tmp = result.filter { $0.overlapping(lesson) }
            for subLesson in tmp {
                if subLesson == lesson {
                    continue
                }

                if lesson.containedIn(subLesson) {
                    result.removeAll(where: { $0 == lesson })
                    continue
                }

                if subLesson.containedIn(lesson) {
                    result.removeAll(where: { $0 == subLesson })
                    continue
                }

                result.removeAll(where: { $0 == lesson || $0 == subLesson })
                result.append(max(lesson, subLesson))
            }
        }
        return result
    }

    static let example = Lesson(classroomName: "5104",
                                courseName: "数学分析B1",
                                startTime: "09:45",
                                endTime: "11:20",
                                color: .blue)
}

func timeToInt(_ time: String) -> Int {
    let tmp = time.split(separator: ":")
    if tmp.count < 2 {
        return 0
    }
    return Int(tmp[0])! * 60 + Int(tmp[1])!
}

func max(_ lhs: Lesson, _ rhs: Lesson) -> Lesson {
    var result = lhs
    if timeToInt(lhs.startTime) > timeToInt(rhs.startTime) {
        result.startTime = rhs.startTime
    }

    if timeToInt(lhs.endTime) < timeToInt(rhs.endTime) {
        result.endTime = rhs.endTime
    }
    result.courseName = "\(lhs.courseName), \(rhs.courseName)"
    result.color = .yellow
    return result
}

class UstcClassroomDelegate: AsyncDataDelegate {
    var requireUpdate: Bool = true
    var cache: [String: JSON] = [:]

    @Published var date = Date()
    @Published var data: [String: [Lesson]] = [:]
    var placeHolderData: [String: [Lesson]] {
        var result: [String: [Lesson]] = [:]
        for building in UstcClassroomDelegate.allBuildings {
            result[building] = [.example]
        }
        return result
    }

    @Published var status: AsyncViewStatus = .inProgress

    func parseCache() async throws -> [String: [Lesson]] {
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

    func refreshCache() async throws {
        for building in UstcClassroomDelegate.allBuildings {
            let validToken = try await validToken()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)

            let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catalog.ustc.edu.cn/api/teach/timetable-public/\(building)/\(dateString)?access_token=\(validToken)")!)
            cache[building] = try JSON(data: data)
        }

        let data = try await parseCache()
        foregroundUpdateData(with: data)
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

    init() {
        userTriggerRefresh(forced: true)
    }
}

extension UstcClassroomDelegate {
    static var shared = UstcClassroomDelegate()
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
