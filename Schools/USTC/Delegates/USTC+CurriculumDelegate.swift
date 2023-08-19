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

class USTCCurriculumDelegate: CurriculumProtocol {
    static let shared = USTCCurriculumDelegate()

    @LoginClient(\.ustcUgAAS) var ugAASClient: UstcUgAASClient
    @LoginClient(\.ustcCatalog) var catalogClient: UstcCatalogClient

    func refreshSemesterList() async throws -> [String: String] {
        [:]
    }

    func refreshSemester(id: String) async throws -> Semester {
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

        let url = URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/\(id)/print-data/\(tableID)?weekIndex=")!
        request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSON(data: data)

//        let semesterName = json["semesterName"].stringValue
        return .example
    }
}
