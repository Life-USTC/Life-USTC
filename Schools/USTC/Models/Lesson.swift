//
//  Lesson.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI  //
// struct Lesson: Identifiable, Equatable, Codable {
//    var id: UUID {
//        UUID(name: "\(classroomName):\(courseName),\(startTime)->\(endTime)", nameSpace: .oid)
//    }
//
//    var classroomName: String
//    var courseName: String
//    var startTime: String // hh:mm
//    var endTime: String // hh:mm
//    var color: Color
//
//    static let example = Lesson(classroomName: "5104",
//                                courseName: "数学分析B1",
//                                startTime: "09:45",
//                                endTime: "11:20",
//                                color: .blue)
// }
//
// extension Lesson {
//    func overlapping(_ other: Lesson) -> Bool {
//        if classroomName != other.classroomName {
//            return false
//        }
//        if timeToInt(other.endTime) <= timeToInt(startTime) || timeToInt(endTime) <= timeToInt(other.startTime) {
//            return false
//        }
//        return true
//    }
//
//    func containedIn(_ other: Lesson) -> Bool {
//        if classroomName != other.classroomName {
//            return false
//        }
//        if timeToInt(startTime) < timeToInt(other.startTime) {
//            return false
//        }
//        if timeToInt(endTime) > timeToInt(other.endTime) {
//            return false
//        }
//        return true
//    }
//
//    static func clean(_ lessons: [Lesson]) -> [Lesson] {
//        // cleaning rules:
//        // 1. same classroom and course name, results start time is the earliest start time, end time is the latest end time, color is the same
//        // 2. same classroom and different course name: (time overlap)
//        // 2.2. if two are not contained in each other, keep both, change course name to "course1, course2", start time is the earliest start time, end time is the latest end time, color is set to YELLOW
//        // 2.1. if one is contained in the other, remove the contained one
//        var result = lessons
//        for lesson in result {
//            let tmp = result.filter { $0.classroomName == lesson.classroomName && $0.courseName == lesson.courseName }
//            if tmp.count > 1 {
//                let startTime = tmp.map(\.startTime).sorted(by: { timeToInt($0) < timeToInt($1) }).first ?? "0"
//                let endTime = tmp.map(\.endTime).sorted(by: { timeToInt($0) < timeToInt($1) }).last ?? "0"
//
//                result.removeAll(where: { $0.classroomName == lesson.classroomName && $0.courseName == lesson.courseName })
//                result.append(Lesson(classroomName: lesson.classroomName, courseName: lesson.courseName, startTime: startTime, endTime: endTime, color: lesson.color))
//            }
//        }
//
//        for lesson in result {
//            let tmp = result.filter { $0.overlapping(lesson) }
//            for subLesson in tmp {
//                if subLesson == lesson {
//                    continue
//                }
//
//                if lesson.containedIn(subLesson) {
//                    result.removeAll(where: { $0 == lesson })
//                    continue
//                }
//
//                if subLesson.containedIn(lesson) {
//                    result.removeAll(where: { $0 == subLesson })
//                    continue
//                }
//
//                result.removeAll(where: { $0 == lesson || $0 == subLesson })
//                result.append(max(lesson, subLesson))
//            }
//        }
//        return result
//    }
// }
//
// func timeToInt(_ time: String) -> Int {
//    let tmp = time.split(separator: ":")
//    if tmp.count < 2 {
//        return 0
//    }
//    return Int(tmp[0])! * 60 + Int(tmp[1])!
// }
//
// func max(_ lhs: Lesson, _ rhs: Lesson) -> Lesson {
//    var result = lhs
//    if timeToInt(lhs.startTime) > timeToInt(rhs.startTime) {
//        result.startTime = rhs.startTime
//    }
//
//    if timeToInt(lhs.endTime) < timeToInt(rhs.endTime) {
//        result.endTime = rhs.endTime
//    }
//    result.courseName = "\(lhs.courseName), \(rhs.courseName)"
//    result.color = .yellow
//    return result
// }
