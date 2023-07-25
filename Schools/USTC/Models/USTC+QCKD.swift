//
//  USTC+QCKD.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import SwiftUI
import SwiftyJSON

class UstcQCKDEvent: Identifiable, Equatable, Codable, ObservableObject {
    private var json: JSON
    var children: [UstcQCKDEvent] = []

    static func == (lhs: UstcQCKDEvent, rhs: UstcQCKDEvent) -> Bool {
        lhs.id == rhs.id
    }

    var id: String {
        json["self"]["id"].stringValue
    }

    var name: String {
        json["self"]["itemName"].stringValue
    }

    var imageURL: URL {
        URL(string: "https://young.ustc.edu.cn/login/\(json["self"]["pic"].stringValue)")!
    }

    var ratingTxt: String {
        "\(json["rating"]["avgNum"].stringValue) [\(json["rating"]["evaluationNum"].stringValue)/\(json["rating"]["registrationNum"].stringValue)]"
    }

    var timeDescription: String {
        "\(json["self"]["st"].stringValue) - \(json["self"]["et"].stringValue)"
    }

    var startTime: String {
        json["self"]["st"].stringValue
    }

    var endTime: String {
        json["self"]["et"].stringValue
    }

    var infoDescription: String {
        "\(json["self"]["moduleName"].stringValue) [\(json["self"]["formName"].stringValue)]"
    }

    var description: String {
        json["self"]["baseContent"].stringValue
    }

    var hostingDepartment: String {
        json["self"]["sponsorNames"].stringValue
    }

    var contactInformation: String {
        json["self"]["linkMan"].stringValue + " " + json["self"]["tel"].stringValue
    }

    init(json: JSON, children: [UstcQCKDEvent] = []) {
        self.json = json
        self.children = children
        // json["self"], json["children"], json["rating"]
    }

    enum CodingKeys: CodingKey {
        case json
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        json = try container.decode(JSON.self, forKey: .json)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(json, forKey: .json)
    }
}

struct UstcQCKDModel: Codable {
    var eventLists: [String: [UstcQCKDEvent]] = [:]

    var availableEvents: [UstcQCKDEvent] {
        eventLists["Available"] ?? []
    }

    var doneEvents: [UstcQCKDEvent] {
        eventLists["Done"] ?? []
    }

    var myEvents: [UstcQCKDEvent] {
        eventLists["My"] ?? []
    }
}

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

    @available(*, renamed: "fetchAvailableEvents(pageNo:)")
    func fetchAvailableEvents(pageNo: Int = 1) async throws -> [UstcQCKDEvent] {
        try await fetchEventList(with: "Available", pageNo: pageNo)
    }

    @available(*, renamed: "fetchDoneEvents(pageNo:)")
    func fetchDoneEvents(pageNo: Int = 1) async throws -> [UstcQCKDEvent] {
        try await fetchEventList(with: "Done", pageNo: pageNo)
    }

    @available(*, renamed: "fetchMyEvents(pageNo:)")
    func fetchMyEvents(pageNo: Int = 1) async throws -> [UstcQCKDEvent] {
        try await fetchEventList(with: "My", pageNo: pageNo)
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
