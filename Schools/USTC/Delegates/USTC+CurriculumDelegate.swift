//
//  CurriculumDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import EventKit
import SwiftUI
import SwiftyJSON
import WidgetKit

class USTCCurriculumDelegate: CurriculumProtocolB & CurriculumProtocol {
    static let shared = USTCCurriculumDelegate()

    @LoginClient(\.ustcUgAAS) var ugAASClient: UstcUgAASClient
    @LoginClient(\.ustcCatalog) var catalogClient: UstcCatalogClient

    func refreshSemesterBase() async throws -> [Semester] {
        func convertYYMMDD(_ date: String) -> Date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.date(from: date)!
        }

        if try await !_catalogClient.requireLogin() {
            throw BaseError.runtimeError("UstcCatalog Not logined")
        }
        let validToken = catalogClient.token

        let url = URL(string: "https://catalog.ustc.edu.cn/api/teach/semester/list?access_token=\(validToken)")!

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)

        var result: [Semester] = []
        for (_, subJson) in json {
            result.append(Semester(id: subJson["id"].stringValue,
                                   courses: [],
                                   name: subJson["nameZh"].stringValue,
                                   startDate: convertYYMMDD(subJson["startDate"].stringValue),
                                   endDate: convertYYMMDD(subJson["endDate"].stringValue)))
        }

        return result
    }

    func refreshSemester(inComplete: Semester) async throws -> Semester {
        let queryURL = URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!
        if try await !_ugAASClient.requireLogin() {
            throw BaseError.runtimeError("UstcUgAAS Not logined")
        }

        var request = URLRequest(url: queryURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await URLSession.shared.data(for: request)

        let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
        var tableID = "0"
        if let match {
            if !match.isEmpty {
                tableID = String(match.first!.0)
            }
        }

        let url = URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(inComplete.id)/print-data/\(tableID)?weekIndex=")!
        request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)

//        let semesterName = json["semesterName"].stringValue
        return .example
    }
}
