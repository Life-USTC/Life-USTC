//
//  USTC+QCKDClient.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/25.
//

import Foundation
import SwiftyJSON

class UstcQCKDClient: ObservableObject {
    static var shared = UstcQCKDClient()

    var session: URLSession = .shared
    var loginCache: JSON = .init()
    var token: String = ""
    var lastLogined: Date?

    func markRequest(request: inout URLRequest) {
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Access-Token")
    }

    func getJSON(from url: URL) async throws -> JSON {
        var request = URLRequest(url: url)
        markRequest(request: &request)
        let (data, _) = try await session.data(for: request)
        return try JSON(data: data)
    }

    func fetchEvent(id: String) async throws -> UstcQCKDEvent {
        if try await !requireLogin() {
            throw BaseError.runtimeError("UstcQCKD Not logined")
        }
        let selfJSON = try await getJSON(from: URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItem/queryById?_t=\(unixTimestamp)&id=\(id)")!)["result"]
        let childrenJSON = try await getJSON(from: URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItem/selectSignChirdItem?_t=\(unixTimestamp)&id=\(id)")!)["result"]
        let ratingJSON = try await getJSON(from: URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/lib/scItemProgramme/selectEvaluationByItemId?_t=\(unixTimestamp)&id=\(id)")!)["result"]

        var json = JSON()
        json["self"] = selfJSON
        json["rating"] = ratingJSON

        var children: [UstcQCKDEvent] = []
        await withTaskGroup(of: UstcQCKDEvent?.self) { group in
            for (_, subJSON) in childrenJSON {
                group.addTask {
                    try? await self.fetchEvent(id: subJSON["id"].stringValue)
                }
            }

            for await child in group {
                if let child {
                    children.append(child)
                }
            }
        }

        return UstcQCKDEvent(json: json, children: children)
    }

    func fetchEventList(with name: String, pageNo: Int = 1) async throws -> [UstcQCKDEvent] {
        if try await !requireLogin() {
            throw BaseError.runtimeError("UstcQCKD Not logined")
        }

        var url: URL?
        switch name {
        case "Available":
            url = URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItem/enrolmentList?_t=\(unixTimestamp)&column=createTime&order=desc&field=id%2C%2Caction&pageNo=\(pageNo)&pageSize=50")!
        case "Done":
            url = URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItem/endList?_t=\(unixTimestamp)&column=createTime&order=desc&field=id,,action&pageNo=\(pageNo)&pageSize=10")!
        case "My":
            url = URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scParticipateItem/list?queryCatelog=0&_t=\(unixTimestamp)&column=createTime&order=desc&field=id,,number,itemName,module_dictText,form_dictText,linkMan,tel,sponsor_dictText,serviceHour,action&pageNo=\(pageNo)&pageSize=10")!
        default:
            throw BaseError.runtimeError("UstcQCKD No such event list")
        }

        let queryJSON = try await getJSON(from: url!)
        var result: [UstcQCKDEvent] = []
        await withTaskGroup(of: UstcQCKDEvent?.self) { group in
            for (_, subJSON) in queryJSON["result"]["records"] {
                group.addTask {
                    try? await self.fetchEvent(id: subJSON["id"].stringValue)
                }
            }

            for await child in group {
                if let child {
                    result.append(child)
                }
            }
        }

        return result
    }

    struct RegisterFormModel: Codable {
        var text_value: String
        var text: String
        var value: String
    }

    func getFormForEvent(id: String) async throws -> [RegisterFormModel] {
        if try await !requireLogin() {
            throw BaseError.runtimeError("UstcQCKD Not logined")
        }
        // GET:  https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItemRegistration/getOptions?_t=1690291186&itemId=3ea2b3f3a1831ee59cd29742e9bb386f

        let url = URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItemRegistration/getOptions?_t=\(unixTimestamp)&itemId=\(id)")!
        let resultJSON = try await getJSON(from: url)["result"]
        // {
        //     "text_value": "",
        //     "text": "手机",
        //     "value": "phone"
        // },
        // {
        //     "text_value": "",
        //     "text": "邮箱",
        //     "value": "email"
        // }
//        print(resultJSON)
//        var result: [String] = []
//        for (_, subJSON) in resultJSON  {
//            result.append(subJSON["text"].stringValue)
//        }
//        return result
        return try JSONDecoder().decode([RegisterFormModel].self, from: try! resultJSON.rawData())
    }

    func registerEvent(id: String, formData: [RegisterFormModel]) async throws -> Bool {
        if try await !requireLogin() {
            throw BaseError.runtimeError("UstcQCKD Not logined")
        }
        // construct POST request to https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItemRegistration/enter/{id}
        // formData are stored in body (json format)

        // formData: {"email": "xx" } -> "{ "email} ..."
        // let formDataEncoded = try JSONSerialization.data(withJSONObject: formData, options: .prettyPrinted)
//        let formDataEncoded = try JSONSerialization.data(withJSONObject: formData.map { [$0.0: $0.1] }, options: .prettyPrinted)
        // let formDataEncoded = try JSONEncoder().encode(formData.map { [$0.value:
        var form = JSON()
        for item in formData {
            form[item.value] = .init(stringLiteral: item.text_value)
        }
        let formDataEncoded = form.rawString() ?? ""
        debugPrint(formDataEncoded)

        var request = URLRequest(url: URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/item/scItemRegistration/enter/\(id)")!)
        markRequest(request: &request)
        request.httpMethod = "POST"
        request.httpBody = formDataEncoded.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        debugPrint(String(data: data, encoding: .utf8))
        debugPrint(response)
        return true
    }

    func login() async throws -> Bool {
        let loginURL = URL(string: "https://young.ustc.edu.cn/login")!
        let casLoginURL = URL(string: "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fyoung.ustc.edu.cn%2Flogin%2Fsc-wisdom-group-learning%2F")!
        let callBackURL = URL(string: "https://young.ustc.edu.cn/loginsc-wisdom-group-learning")!
        print("network<UstcQCKD>: login called")

        _ = try await session.data(from: loginURL)
        let tmpCASSession = UstcCasClient(session: session)
        _ = try await tmpCASSession.loginToCAS(url: casLoginURL, service: callBackURL)
        var request = URLRequest(url: casLoginURL)
        request.httpMethod = "GET"
        let (_, response) = try await session.data(for: request)
        //        correct.
        //        debugPrint(response)
        //        debugPrint(String(data: data, encoding: .utf8))
        guard let url = response.url,
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let stToken = urlComponents.queryItems?.first(where: { $0.name == "ticket" })?.value
        else {
            throw BaseError.runtimeError("No ticket find for ustc qckd")
        }

        //        let unixTimestamp = Int(Date().timeIntervalSince1970)
        //        print(unixTimestamp)

        let fetchTokenURL = URL(string: "https://young.ustc.edu.cn/login/wisdom-group-learning-bg/cas/client/checkSsoLogin?_t=\(unixTimestamp)&ticket=\(stToken)&service=https:%2F%2Fyoung.ustc.edu.cn%2Flogin%2Fsc-wisdom-group-learning%2F")!

        request = URLRequest(url: fetchTokenURL)
        request.httpMethod = "GET"
        //        let (fetchTokenData, fetchTokenResponse) = try await session.data(for: request)
        let (fetchTokenData, _) = try await session.data(for: request)
        //        debugPrint(fetchTokenResponse)
        //        debugPrint(String(data: fetchTokenData, encoding: .utf8))

        loginCache = try JSON(data: fetchTokenData)

        guard let token = loginCache["result"]["token"].string else {
            throw BaseError.runtimeError("No token find for ustc qckd")
        }

        self.token = token

        //        session.configuration.httpCookieStorage?.cookies?.append()
        //        session

        print("network<UstcQCKD>: Login finished")
        lastLogined = .now
        return true // I honsetly don't see the point of this though ...
    }

    func checkLogined() -> Bool {
        if lastLogined == nil || Date() > lastLogined! + DateComponents(minute: 5) {
            print("network<UstcQCKD>: Not logged in, [REQUIRE LOGIN]")
            return false
        }
        //        print("network<UstcQCKD>: Already logged in, passing")
        return true
    }

    var loginTask: Task<Bool, Error>?

    func requireLogin() async throws -> Bool {
        if let loginTask {
            print("network<UstcQCKD>: login task already running, [WAITING RESULT]")
            return try await loginTask.value
        }

        if checkLogined() {
            return true
        }

        let task = Task {
            do {
                print("network<UstcQCKD>: No login task running, [CREATING NEW ONE]")
                let result = try await self.login()
                loginTask = nil
                print("network<UstcQCKD>: login task finished, result:\(result)")
                return result
            } catch {
                loginTask = nil
                throw (error)
            }
        }
        loginTask = task
        return try await task.value
    }

    func clearLoginStatus() {
        lastLogined = nil
    }
}
