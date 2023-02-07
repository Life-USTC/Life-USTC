//
//  UstcWeixin.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/3.
//

import Foundation
import SwiftSoup

class UstcWeixinClient: ObservableObject {
    static var main = UstcWeixinClient()

    @Published var lastReportedHealth: Date?

    func loadCache() {
        do {
            let decoder = JSONDecoder()
            if let data = userDefaults.data(forKey: "UstcWeixinLastRepotedHealth") {
                lastReportedHealth = try decoder.decode(Date?.self, from: data)
            }
        } catch {
            print(error)
        }
    }

    func saveCache() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(lastReportedHealth)
            userDefaults.set(data, forKey: "UstcWeixinLastRepotedHealth")
        } catch {
            print(error)
        }
    }

    func dailyReportHealth() async throws -> Bool {
        print("!!! Daily health report")

        if try await !UstcCasClient.main.requireLogin() {
            return false
        }

        let session = URLSession.shared
        let (data, _) = try await session.data(from: URL(string: "https://weixine.ustc.edu.cn/2020/caslogin")!.ustcCASLoginMarkup())

        guard let dataString = String(data: data, encoding: .utf8) else {
            return false
        }
        let document: Document = try SwiftSoup.parse(dataString)

        guard let match = dataString.firstMatch(of: try Regex("[a-zA-Z0-9]{18,}")) else {
            return false
        }

        var dataList: [String] = []
        let keyList = ["juzhudi", "jinji_lxr", "jinji_guanxi", "jiji_mobile"]

        for _key in keyList {
            if let tmpString = userDefaults.string(forKey: _key) {
                if !tmpString.isEmpty {
                    dataList.append(tmpString)
                    continue
                }
            }
            let tmpElment = try document.select("input.form-control[name=\(_key)]")
            let parsedTmpString = try tmpElment.attr("value")
            dataList.append(parsedTmpString)
            userDefaults.set(parsedTmpString, forKey: _key)
        }

        let queryString = "_token=\(String(match.0).urlEncoded!)&juzhudi=\(dataList[0].urlEncoded!)&q_0=\("良好".urlEncoded!)&body_condition_detail=&q_2=&q_3=&jinji_lxr=\(dataList[1].urlEncoded!)&jinji_guanxi=\(dataList[2].urlEncoded!)&jiji_mobile=\(dataList[3].urlEncoded!)&other_detail="

        var request = URLRequest(url: URL(string: "https://weixine.ustc.edu.cn/2020/daliy_report")!)
        request.httpMethod = "POST"
        request.httpBody = queryString.data(using: .utf8)

        _ = try await session.data(for: request)

        DispatchQueue.main.async {
            self.lastReportedHealth = Date()
            self.saveCache()
            self.objectWillChange.send()
        }
        return true
    }

    init() {
        loadCache()
    }
}
