import Foundation
import Network

/// A loopback HTTP peer for native UI tests. It supplies fixed wire responses;
/// its test token is not an OAuth grant and does not establish server authorization.
final class ServerJourneyHTTPFixture {
    struct Request {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let body: Data

        var jsonBody: [String: Any] {
            (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        }
    }

    enum StartError: Error {
        case listenerNotReady
    }

    static let token = "native-journey-fixture-token"

    private let queue = DispatchQueue(label: "LifeUSTC.ServerJourneyFixture")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var received: [Request] = []
    private var membership: [Int: String] = [43: "teaching_assistant"]
    private var pendingCatalogFailure = false
    private var pendingSubscriptionFailure = false
    private var workspace: WorkspaceLearningHTTPState?
    private var community: CommunityHTTPState?
    private var campus: CampusHTTPState?
    private var youngCampus: YoungCampusHTTPState?
    private var accountJourney: AccountJourneyHTTPState?
    private let catalogHistory: Bool
    private var failedRequest: (method: String, path: String)?

    init(workspace: Bool = false, community: Bool = false, campus: Bool = false, youngCampus: Bool = false, accountJourney: Bool = false, catalogHistory: Bool = false) {
        self.catalogHistory = catalogHistory
        if catalogHistory { membership = [42: "regular", 43: "teaching_assistant"] }
        if workspace { self.workspace = WorkspaceLearningHTTPState(todoState: WorkspaceTodoHTTPState()) }
        if community { self.community = CommunityHTTPState() }
        if campus { self.campus = CampusHTTPState() }
        if youngCampus { self.youngCampus = YoungCampusHTTPState() }
        if accountJourney { self.accountJourney = AccountJourneyHTTPState() }
    }

    var requests: [Request] { queue.sync { received } }
    var subscriptionKinds: [Int: String] { queue.sync { membership } }
    var workspaceTodos: [[String: Any]] { queue.sync { workspace?.todoState.todos ?? [] } }
    var workspaceHomeworks: [[String: Any]] { queue.sync { workspace?.homeworks ?? [] } }
    var communityComments: [[String: Any]] { queue.sync { community?.comments ?? [] } }
    var communityHomeworks: [[String: Any]] { queue.sync { community?.homeworks ?? [] } }
    var communityUploads: [[String: Any]] { queue.sync { community?.uploads ?? [] } }

    func hideCommunityComments() { queue.sync { community?.hideAllComments() } }
    func enableBusParityFixture() { queue.sync { campus?.busParity = true } }
    func includeHistoricalSubscription() { queue.sync { membership[44] = "regular" } }

    func failNextRequest(method: String, path: String) {
        queue.sync { failedRequest = (method, path) }
    }

    func failNextCatalogRead() {
        queue.sync { pendingCatalogFailure = true }
    }

    func failNextSubscriptionWrite() {
        queue.sync { pendingSubscriptionFailure = true }
    }

    func start() throws -> URL {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed:
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.connections.append(connection)
            connection.start(queue: self.queue)
            self.receive(connection, buffered: Data())
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success,
              let port = listener.port,
              let url = URL(string: "http://127.0.0.1:\(port.rawValue)")
        else {
            listener.cancel()
            throw StartError.listenerNotReady
        }
        return url
    }

    func stop() {
        queue.sync {
            connections.forEach { $0.cancel() }
            connections.removeAll()
            listener?.cancel()
            listener = nil
        }
    }

    private func receive(_ connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, finished, error in
            guard let self else { return }
            var buffer = buffered
            if let data { buffer.append(data) }
            guard buffer.count <= 131_072 else {
                connection.cancel()
                return
            }
            if let request = self.parseRequest(buffer) {
                self.received.append(request)
                let response = self.response(to: request)
                self.send(response.body, status: response.status, to: connection)
            } else if !finished && error == nil {
                self.receive(connection, buffered: buffer)
            } else {
                connection.cancel()
            }
        }
    }

    private func parseRequest(_ data: Data) -> Request? {
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<boundary.lowerBound], encoding: .utf8)
        else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count == 3,
              let url = URLComponents(string: "http://127.0.0.1\(requestLine[1])")
        else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
        }
        let body = Data(data[boundary.upperBound...])
        let length = Int(headers["content-length"] ?? "0") ?? 0
        guard body.count >= length else { return nil }
        var query: [String: String] = [:]
        for item in url.queryItems ?? [] { query[item.name] = item.value }
        return Request(
            method: String(requestLine[0]), path: url.path, query: query,
            headers: headers, body: Data(body.prefix(length))
        )
    }

    private func send(_ object: Any, status: Int, to connection: NWConnection) {
        guard let body = object as? Data ?? (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) else {
            connection.cancel()
            return
        }
        let reason = status == 200 ? "OK" : "Fixture Failure"
        let head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func response(to request: Request) -> (status: Int, body: Any) {
        if request.path.hasPrefix("/api/workspace/") || request.path == "/api/account/profile" {
            guard request.headers["authorization"] == "Bearer \(Self.token)" else {
                return (401, ["error": "Fixture sign-in required"])
            }
        }

        if let failedRequest, request.method == failedRequest.method, request.path == failedRequest.path {
            self.failedRequest = nil
            return (503, ["error": "Workspace fixture unavailable"])
        }
        if let response = accountJourney?.response(to: request) { return response }
        if let response = campus?.response(to: request) { return response }
        if let response = youngCampus?.response(to: request) { return response }
        if let response = community?.response(to: request) { return response }
        if let response = workspace?.response(to: request) { return response }

        switch (request.method, request.path) {
        case ("GET", "/api/community/comments"):
            guard request.query["targetType"] == "section", request.query["targetId"] == "7",
                  request.query["sectionId"] == nil
            else { return (400, ["error": "Expected internal section target ID 7"]) }
            return (200, ["data": [], "pagination": ["page": 1, "pageSize": 20, "total": 0, "totalPages": 0],
                          "meta": ["hiddenCount": 0,
                                   "viewer": ["isAdmin": false, "isAuthenticated": false, "isSuspended": false],
                                   "target": ["type": "section", "targetId": "7"]]])
        case ("GET", "/api/account/profile"):
            return (200, ["id": "fixture-student", "name": "Fixture Student", "username": "fixture-student",
                          "email": NSNull(), "image": NSNull(), "isAdmin": NSNull()])
        case ("GET", "/api/catalog/semesters/current"):
            return (200, Self.semester)
        case ("GET", "/api/catalog/semesters"):
            return (200, Self.page(catalogHistory ? [Self.semester, Self.springSemester] : [Self.semester], pageSize: 100))
        case ("GET", "/api/catalog/metadata"):
            return (200, ["educationLevels": [
                ["id": 1, "nameCn": "本科生", "nameEn": "Undergraduate"],
                ["id": 2, "nameCn": "研究生", "nameEn": "Graduate"],
            ]])
        case ("GET", "/api/catalog/courses"):
            let search = request.query["search"]?.lowercased() ?? ""
            let courses = [Self.course(1001), Self.course(1002)].filter {
                (request.query["educationLevelId"] == nil || String($0["educationLevelId"] as? Int ?? -1) == request.query["educationLevelId"])
                    && (search.isEmpty || ($0["nameCn"] as? String ?? "").lowercased().contains(search))
            }
            return (200, Self.page(courses, pageSize: 30))
        case ("GET", "/api/catalog/courses/1001"), ("GET", "/api/catalog/courses/1002"):
            let calculus = request.path.hasSuffix("1001")
            var course = Self.course(calculus ? 1001 : 1002)
            course["sections"] = [Self.section(calculus ? 42 : 43)]
            return (200, course)
        case ("GET", "/api/catalog/courses/1001/sections"):
            return (200, Self.page(catalogHistory ? [catalogSection(42), catalogSection(44)] : [Self.section(42)], pageSize: 100))
        case ("GET", "/api/catalog/courses/1002/sections"):
            return (200, Self.page([catalogSection(43)], pageSize: 100))
        case ("GET", "/api/catalog/teachers/3/sections"):
            return (200, Self.page(catalogHistory ? [catalogSection(42), catalogSection(43), catalogSection(44)] : [Self.section(42), Self.section(43)], pageSize: 100))
        case ("GET", "/api/catalog/teachers"):
            let search = request.query["search"]?.lowercased() ?? ""
            let teachers = [Self.teacher].filter {
                search.isEmpty || ($0["nameCn"] as? String ?? "").lowercased().contains(search)
            }
            return (200, Self.page(teachers, pageSize: 30))
        case ("GET", "/api/catalog/teachers/3"):
            var teacher = Self.teacher
            teacher["sections"] = [Self.section(42), Self.section(43)]
            return (200, teacher)
        case ("GET", "/api/catalog/sections"):
            if pendingCatalogFailure {
                pendingCatalogFailure = false
                return (503, ["error": "Catalog fixture unavailable"])
            }
            let sections = [Self.section(42), Self.section(43)].filter { section in
                if let courseID = request.query["courseId"] {
                    let course = section["course"] as? [String: Any]
                    if String(course?["id"] as? Int ?? -1) != courseID { return false }
                }
                if let teacherID = request.query["teacherId"], teacherID != "3" { return false }
                return true
            }
            let search = request.query["search"]?.lowercased() ?? ""
            let filtered = search.isEmpty ? sections : sections.filter {
                let course = $0["course"] as? [String: Any]
                return (course?["nameCn"] as? String ?? "").lowercased().contains(search)
            }
            return (200, Self.page(filtered, pageSize: Int(request.query["pageSize"] ?? "30") ?? 30))
        case ("GET", "/api/catalog/sections/42"), ("GET", "/api/catalog/sections/43"):
            let jwID = request.path.hasSuffix("42") ? 42 : 43
            return (200, catalogSection(jwID))
        case ("GET", "/api/catalog/sections/44") where catalogHistory:
            return (200, catalogSection(44))
        case ("GET", "/api/catalog/sections/42/schedules"), ("GET", "/api/catalog/sections/43/schedules"), ("GET", "/api/catalog/sections/44/schedules"):
            if request.query["page"] != nil || request.query["pageSize"] != nil {
                guard request.query["page"] == "1", request.query["pageSize"] == "100"
                else { return (400, ["error": "Expected the section's first schedule page"]) }
                return (200, Self.page([Self.schedule], pageSize: 100))
            }
            return (200, [Self.schedule])
        case ("GET", "/api/workspace/subscriptions/current"):
            return (200, ["subscription": subscription])
        case ("PATCH", "/api/workspace/subscriptions"):
            if pendingSubscriptionFailure {
                pendingSubscriptionFailure = false
                return (503, ["error": "Subscription fixture unavailable"])
            }
            guard request.jsonBody["sectionIds"] as? [Int] == [7] else {
                return (400, ["error": "Expected internal section ID 7"])
            }
            let alreadySubscribed = membership[42] != nil
            if !alreadySubscribed { membership[42] = "regular" }
            return (200, ["subscription": subscription, "addedCount": alreadySubscribed ? 0 : 1,
                          "alreadySubscribedCount": alreadySubscribed ? 1 : 0])
        case ("DELETE", "/api/workspace/subscriptions"):
            guard request.jsonBody["sectionIds"] as? [Int] == [7] else {
                return (400, ["error": "Expected internal section ID 7"])
            }
            membership.removeValue(forKey: 42)
            return (200, ["subscription": subscription])
        case ("PATCH", "/api/workspace/subscriptions/42"):
            guard membership[42] != nil else { return (404, ["error": "Subscription not found"]) }
            guard let kind = request.jsonBody["kind"] as? String,
                  ["regular", "auditor", "teaching_assistant"].contains(kind)
            else { return (400, ["error": "Invalid subscription kind"]) }
            membership[42] = kind
            return (200, ["sectionJwId": 42, "kind": kind])
        case ("GET", "/api/workspace/calendar/events"):
            let day = String((request.query["dateFrom"] ?? "2026-10-23").prefix(10))
            let event: [String: Any] = [
                "id": "schedule:901", "type": "schedule", "title": "Server-dated seminar",
                "at": "\(day)T08:15:00+08:00", "endsAt": "\(day)T09:45:00+08:00",
                "location": "East Campus 2201", "url": "/catalog/sections/42", "youngId": NSNull(),
            ]
            return (200, Self.page([event], pageSize: 100))
        default:
            return (404, ["error": "Unconfigured fixture route: \(request.method) \(request.path)"])
        }
    }

    private var subscription: [String: Any] {
        let sections = membership.keys.sorted().map { jwID -> [String: Any] in
            var section = catalogSection(jwID)
            section["kind"] = membership[jwID]
            return section
        }
        return ["userId": "fixture-student", "sections": sections,
                "calendarPath": NSNull(),
                "calendarUrl": workspace == nil ? NSNull() : "https://fixture.invalid/calendar/native-journey.ics" as Any,
                "note": ""]
    }

    private static func page(_ data: [[String: Any]], pageSize: Int) -> [String: Any] {
        ["data": data, "pagination": ["page": 1, "pageSize": pageSize,
                                      "total": data.count, "totalPages": data.isEmpty ? 0 : 1]]
    }

    private static let semester: [String: Any] = [
        "id": 1, "jwId": 101, "code": "2026-FALL", "nameCn": "2026 Fall",
        "startDate": "2026-09-01T00:00:00+08:00", "endDate": "2027-01-31T00:00:00+08:00",
    ]

    private static let springSemester: [String: Any] = [
        "id": 2, "jwId": 102, "code": "2026-SPRING", "nameCn": "2026年春季学期",
        "startDate": "2026-02-01T00:00:00+08:00", "endDate": "2026-07-31T00:00:00+08:00",
    ]

    private func catalogSection(_ jwID: Int) -> [String: Any] {
        guard catalogHistory else { return Self.section(jwID) }
        var section = Self.section(jwID == 44 ? 42 : jwID)
        if jwID == 43 || jwID == 44 { section["semester"] = Self.springSemester }
        if jwID == 44 {
            section["id"] = 9
            section["jwId"] = 44
            section["code"] = "MATH101.OLD"
            section["retiredAt"] = "2026-08-01T00:00:00+08:00"
        }
        return section
    }

    private static let schedule: [String: Any] = [
        "id": 901, "periods": 1.5, "date": "2026-10-23T00:00:00+08:00", "weekday": 5,
        "startTime": "08:15", "endTime": "09:45", "weekIndex": 1,
        "startUnit": 1, "endUnit": 2, "customPlace": "East Campus 2201",
        "room": ["id": 61, "namePrimary": "East Campus 2201",
                 "building": ["id": 62, "namePrimary": "Teaching Building 2",
                              "campus": ["id": 1, "nameCn": "East Campus", "nameEn": "East Campus"]]],
        "teachers": [["id": 3, "nameCn": "Ada Teacher", "nameEn": "Ada Teacher"]],
    ]

    private static let teacher: [String: Any] = [
        "id": 3, "nameCn": "Ada Teacher", "nameEn": "Ada Teacher", "code": "T003",
        "department": ["id": 4, "nameCn": "Mathematics", "nameEn": "Mathematics"],
        "teacherTitle": ["id": 5, "nameCn": "Professor", "nameEn": "Professor"],
    ]

    private static let exams: [[String: Any]] = [
        ["id": 701, "examDate": "2026-12-23", "startTime": 900, "endTime": 1100,
         "examRooms": [["id": 801, "room": "Exam Hall 1"]]],
        ["id": 702, "examDate": NSNull(), "startTime": NSNull(), "endTime": NSNull(),
         "examRooms": [["id": 802, "room": "Exam Hall 2"]]],
    ]

    private static func course(_ jwID: Int) -> [String: Any] {
        let calculus = jwID == 1001
        return [
            "id": calculus ? 11 : 12, "jwId": calculus ? 1001 : 1002,
            "code": calculus ? "MATH101" : "PHYS101",
            "educationLevelId": calculus ? 1 : 2,
            "nameCn": calculus ? "Calculus" : "Physics", "nameEn": calculus ? "Calculus" : "Physics",
        ]
    }

    private static func section(_ jwID: Int) -> [String: Any] {
        let calculus = jwID == 42
        return [
            "id": calculus ? 7 : 8, "jwId": jwID, "code": calculus ? "MATH101.01" : "PHYS101.01",
            "credits": 4.0, "period": 64, "course": course(calculus ? 1001 : 1002), "semester": semester,
            "teachers": [teacher],
            "schedules": [schedule], "scheduleGroups": [], "exams": calculus ? exams : [],
        ]
    }
}
