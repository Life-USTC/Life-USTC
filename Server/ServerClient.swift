//
//  ServerClient.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation
import KeychainAccess

extension Notification.Name {
    static let serverSessionDidChange = Notification.Name("serverSessionDidChange")
}

#if DEBUG
private final class UITestTokenStore: TokenStore, @unchecked Sendable {
    var accessToken: String
    var refreshToken = ""

    init(accessToken: String) { self.accessToken = accessToken }
    func clear() { accessToken = ""; refreshToken = "" }
}
#endif

private let logger = AppLogger.logger(for: "ServerClient")

private final class ServerBinaryTaskDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

// MARK: - Token Store Protocol

/// Abstracts token persistence so tests can use an in-memory store.
protocol TokenStore: Sendable {
    var accessToken: String { get set }
    var refreshToken: String { get set }
    func clear()
}

/// Production token store backed by Keychain (shared via app group).
final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let keychain: Keychain

    init(
        service: String = "dev.tiankaima.Life-USTC",
        accessGroup: String = "group.dev.tiankaima.Life-USTC"
    ) {
        self.keychain = Keychain(service: service, accessGroup: accessGroup)
    }

    var accessToken: String {
        get { (try? keychain.getString("serverAccessToken")) ?? "" }
        set { keychain["serverAccessToken"] = newValue }
    }

    var refreshToken: String {
        get { (try? keychain.getString("serverRefreshToken")) ?? "" }
        set { keychain["serverRefreshToken"] = newValue }
    }

    func clear() {
        keychain["serverAccessToken"] = nil
        keychain["serverRefreshToken"] = nil
    }
}

// MARK: - Server Environment

/// Known backend environments for the app.
enum ServerEnvironment: String, CaseIterable, Identifiable {
    case production = "https://life-ustc.tiankaima.dev"
    case localhost = "http://localhost:3000"
    case custom = ""

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .production: "Production"
        case .localhost: "Localhost (Simulator)"
        case .custom: "Custom URL"
        }
    }

    var url: URL? {
        URL(string: rawValue)
    }
}

// MARK: - Server Client Configuration

struct ServerClientConfiguration {
    let baseURL: URL
    let session: URLSession
    var tokenStore: TokenStore

    #if DEBUG
    static var uiTestBaseURL: URL? {
        guard let raw = ProcessInfo.processInfo.environment["UI_TEST_SERVER_URL"],
            let url = URL(string: raw), url.scheme == "http",
            ["127.0.0.1", "localhost", "::1"].contains(url.host ?? ""),
            url.user == nil, url.password == nil
        else { return nil }
        return url
    }
    #endif

    /// Resolve baseURL from user preference → Info.plist → production default.
    static var resolvedBaseURL: URL {
        #if DEBUG
        if let url = uiTestBaseURL { return url }
        #endif
        // 1. Check user override (debug mode)
        if let stored = UserDefaults.standard.string(forKey: "serverBaseURL"),
           !stored.isEmpty,
           let url = URL(string: stored)
        {
            logger.info("Using server URL from user settings: \(stored)")
            return url
        }

        // 2. Check Info.plist override
        if let override = Bundle.main.object(forInfoDictionaryKey: "ServerBaseURL") as? String,
           let url = URL(string: override)
        {
            logger.info("Using server URL from Info.plist: \(override)")
            return url
        }

        // 3. Default production
        return URL(string: ServerEnvironment.production.rawValue)!
    }

    /// Default configuration.
    static var `default`: ServerClientConfiguration {
        let baseURL = resolvedBaseURL

        #if DEBUG
        if uiTestBaseURL != nil {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            return ServerClientConfiguration(
                baseURL: baseURL,
                session: URLSession(configuration: configuration),
                tokenStore: UITestTokenStore(
                    accessToken: ProcessInfo.processInfo.environment["UI_TEST_SERVER_ACCESS_TOKEN"] ?? ""
                )
            )
        }
        #endif

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "Life-USTC-iOS/\(Bundle.main.releaseNumber ?? "unknown")",
        ]
        config.timeoutIntervalForRequest = 30

        return ServerClientConfiguration(
            baseURL: baseURL,
            session: URLSession(configuration: config),
            tokenStore: KeychainTokenStore()
        )
    }
}

// MARK: - Error Types

enum ServerError: LocalizedError {
    case notAuthenticated
    case forbidden(String)
    case badRequest(String)
    case notFound
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "Not signed in to server")
        case .forbidden(let msg):
            return msg
        case .badRequest(let msg):
            return msg
        case .notFound:
            return String(localized: "Resource not found")
        case .serverError(let msg):
            return msg
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Server Client

final class ServerClient: @unchecked Sendable {
    static let shared = ServerClient()

    private(set) var baseURL: URL
    private var session: URLSession
    var tokenStore: TokenStore
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    /// Lock protecting baseURL + session mutations during reconfigure.
    private let configLock = NSLock()
    private var revision = UUID()
    private var refreshOperation: (id: UUID, revision: UUID, task: Task<Void, Error>)?

    var sessionRevision: UUID { configLock.withLock { revision } }

    var authorizationContext: (baseURL: URL, revision: UUID) {
        configLock.withLock { (baseURL, revision) }
    }

    // MARK: Convenience accessors

    var accessToken: String {
        get { tokenStore.accessToken }
        set { tokenStore.accessToken = newValue }
    }

    var refreshToken: String {
        get { tokenStore.refreshToken }
        set { tokenStore.refreshToken = newValue }
    }

    var isAuthenticated: Bool {
        !accessToken.isEmpty
    }

    // MARK: Init

    init(configuration: ServerClientConfiguration = .default) {
        self.baseURL = configuration.baseURL
        self.session = configuration.session
        self.tokenStore = configuration.tokenStore

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime, .withFractionalSeconds,
            ]
            if let date = formatter.date(from: dateString) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public API

    func request<T: Decodable>(
        _ endpoint: ServerEndpoint,
        retry: Bool = true
    ) async throws -> T {
        try await request(endpoint, retry: retry, expectedRevision: sessionRevision)
    }

    func request<T: Decodable>(
        _ endpoint: ServerEndpoint, retry: Bool = true, expectedRevision: UUID
    ) async throws -> T {
        try Task.checkCancellation()
        let configuration = try configLock.withLock {
            guard expectedRevision == revision else { throw CancellationError() }
            return (baseURL, session, revision, tokenStore.accessToken)
        }
        var urlRequest = endpoint.buildURLRequest(baseURL: configuration.0)

        if !configuration.3.isEmpty {
            urlRequest.setValue(
                "Bearer \(configuration.3)",
                forHTTPHeaderField: "Authorization"
            )
        }

        if let body = endpoint.body {
            urlRequest.httpBody = try encoder.encode(body)
            urlRequest.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }

        logger.debug(
            "\(urlRequest.httpMethod ?? "GET") \(urlRequest.url?.absoluteString ?? "")"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await configuration.1.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw ServerError.networkError(error)
        }

        guard configuration.2 == sessionRevision else { throw CancellationError() }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.networkError(URLError(.badServerResponse))
        }

        logger.debug(
            "← \(httpResponse.statusCode) (\(data.count) bytes) \(urlRequest.url?.path ?? "")"
        )

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error(
                    "Decode error for \(urlRequest.url?.path ?? ""): \(String(describing: error))"
                )
                throw ServerError.decodingError(error)
            }
        case 401:
            let refresh = try configLock.withLock {
                guard expectedRevision == revision else { throw CancellationError() }
                return (available: !tokenStore.refreshToken.isEmpty,
                        needed: tokenStore.accessToken == configuration.3)
            }
            if retry, refresh.available {
                if refresh.needed {
                    try await refreshAccessToken(expectedRevision: configuration.2)
                }
                return try await request(endpoint, retry: false, expectedRevision: expectedRevision)
            }
            logger.warning("Unauthorized (no refresh token available)")
            throw ServerError.notAuthenticated
        case 403:
            let errResp = try? decoder.decode(ServerErrorResponse.self, from: data)
            logger.warning("Forbidden: \(errResp?.error ?? "unknown")")
            throw ServerError.forbidden(errResp?.error ?? "Forbidden")
        case 400:
            let errResp = try? decoder.decode(ServerErrorResponse.self, from: data)
            logger.warning("Bad request: \(errResp?.error ?? "unknown")")
            throw ServerError.badRequest(errResp?.error ?? "Bad request")
        case 404:
            throw ServerError.notFound
        default:
            let errResp = try? decoder.decode(ServerErrorResponse.self, from: data)
            let msg = errResp?.error ?? "Server error (\(httpResponse.statusCode))"
            logger.error("Server error \(httpResponse.statusCode): \(msg)")
            throw ServerError.serverError(msg)
        }
    }

    func requestBinary(_ request: URLRequest, expectedRevision: UUID) async throws -> Data {
        try await requestBinary(request, expectedRevision: expectedRevision, retry: true)
    }

    private func requestBinary(
        _ request: URLRequest, expectedRevision: UUID, retry: Bool
    ) async throws -> Data {
        try Task.checkCancellation()
        let configuration = try configLock.withLock {
            guard expectedRevision == revision else { throw CancellationError() }
            return (baseURL, session, tokenStore.accessToken)
        }
        func port(_ url: URL) -> Int { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              scheme == configuration.0.scheme?.lowercased(),
              url.host?.lowercased() == configuration.0.host?.lowercased(),
              port(url) == port(configuration.0), url.user == nil, url.password == nil,
              ["GET", "PUT"].contains(request.httpMethod ?? "GET") else {
            throw ServerError.badRequest("Invalid attachment request")
        }
        guard !configuration.2.isEmpty else { throw ServerError.notAuthenticated }
        var authorized = request
        authorized.setValue("Bearer \(configuration.2)", forHTTPHeaderField: "Authorization")
        authorized.setValue(nil, forHTTPHeaderField: "Cookie")
        authorized.httpShouldHandleCookies = false
        authorized.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await configuration.1.data(for: authorized, delegate: ServerBinaryTaskDelegate())
        } catch {
            guard expectedRevision == sessionRevision else { throw CancellationError() }
            try Task.checkCancellation()
            throw ServerError.networkError(error)
        }
        try Task.checkCancellation()
        guard expectedRevision == sessionRevision else { throw CancellationError() }
        guard let response = response as? HTTPURLResponse else {
            throw ServerError.networkError(URLError(.badServerResponse))
        }
        switch response.statusCode {
        case 200...299: return data
        case 401:
            let refresh = try configLock.withLock {
                guard expectedRevision == revision else { throw CancellationError() }
                return (available: !tokenStore.refreshToken.isEmpty,
                        needed: tokenStore.accessToken == configuration.2)
            }
            if retry, refresh.available {
                if refresh.needed { try await refreshAccessToken(expectedRevision: expectedRevision) }
                return try await requestBinary(request, expectedRevision: expectedRevision, retry: false)
            }
            throw ServerError.notAuthenticated
        case 403: throw ServerError.forbidden("Attachment access denied")
        case 400: throw ServerError.badRequest("Invalid attachment request")
        case 404: throw ServerError.notFound
        default: throw ServerError.serverError("Attachment request failed (\(response.statusCode))")
        }
    }

    /// Fire a request that returns no meaningful body (e.g. DELETE).
    func requestVoid(_ endpoint: ServerEndpoint) async throws {
        let _: SuccessResponse = try await request(endpoint)
    }

    // MARK: - Form Encoding

    /// Encodes key-value pairs for application/x-www-form-urlencoded.
    static func formEncode(_ params: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params
            .map { key, value in
                let k =
                    key.addingPercentEncoding(
                        withAllowedCharacters: allowed) ?? key
                let v =
                    value.addingPercentEncoding(
                        withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8)!
    }

    // MARK: - Token Refresh

    private func refreshAccessToken(expectedRevision: UUID) async throws {
        let operation = try configLock.withLock { () throws -> (id: UUID, revision: UUID, task: Task<Void, Error>) in
            guard expectedRevision == revision else { throw CancellationError() }
            if let existing = refreshOperation, existing.revision == expectedRevision {
                return existing
            }
            let operation = (id: UUID(), revision: expectedRevision, task: Task {
                try await self.performTokenRefresh(expectedRevision: expectedRevision)
            })
            refreshOperation = operation
            return operation
        }
        defer {
            configLock.withLock {
                if refreshOperation?.id == operation.id { refreshOperation = nil }
            }
        }
        try await operation.task.value
    }

    private func performTokenRefresh(expectedRevision: UUID) async throws {
        let configuration = configLock.withLock { (baseURL, session, revision, refreshToken) }
        guard expectedRevision == configuration.2 else { throw CancellationError() }
        let url = configuration.0.appendingPathComponent("api/auth/oauth2/token")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let bodyParams: [(String, String)] = [
            ("grant_type", "refresh_token"),
            ("refresh_token", configuration.3),
            ("client_id", ServerAuth.clientID),
        ]
        urlRequest.httpBody = Self.formEncode(bodyParams)

        logger.info("Refreshing access token")

        let (data, response) = try await configuration.1.data(for: urlRequest)

        guard expectedRevision == sessionRevision else { throw CancellationError() }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.networkError(URLError(.badServerResponse))
        }
        guard httpResponse.statusCode == 200 else {
            logger.error("Token refresh failed (\(httpResponse.statusCode))")
            let errorResponse = try? decoder.decode(ServerErrorResponse.self, from: data)
            // Only an explicit rejected grant invalidates the session and its offline cache.
            if httpResponse.statusCode == 400, errorResponse?.error == "invalid_grant" {
                guard clearTokens(expectedRevision: expectedRevision) else { throw CancellationError() }
                throw ServerError.notAuthenticated
            }
            throw ServerError.serverError("Token refresh failed (\(httpResponse.statusCode))")
        }

        let tokenResponse = try decoder.decode(OAuthTokenResponse.self, from: data)
        try configLock.withLock {
            guard expectedRevision == revision else { throw CancellationError() }
            tokenStore.accessToken = tokenResponse.accessToken
            if let newRefresh = tokenResponse.refreshToken {
                tokenStore.refreshToken = newRefresh
            }
        }
        logger.info("Token refresh succeeded")
    }

    // MARK: - Session

    func acceptAuthorization(_ response: OAuthTokenResponse, expectedRevision: UUID) throws {
        try configLock.withLock {
            guard revision == expectedRevision else { throw CancellationError() }
            tokenStore.accessToken = response.accessToken
            tokenStore.refreshToken = response.refreshToken ?? ""
            revision = UUID()
        }
        NotificationCenter.default.post(name: .serverSessionDidChange, object: self)
    }

    @discardableResult
    func clearTokens(expectedRevision: UUID? = nil) -> Bool {
        let cleared = configLock.withLock {
            if let expectedRevision, expectedRevision != revision { return false }
            tokenStore.clear()
            revision = UUID()
            return true
        }
        if cleared {
            logger.info("Cleared stored tokens")
            NotificationCenter.default.post(name: .serverSessionDidChange, object: self)
        }
        return cleared
    }

    /// Atomically switch the backend URL. Clears tokens since they belong to the old server.
    func reconfigure(baseURL newURL: URL) {
        configLock.lock()

        let oldHost = baseURL.host() ?? ""
        logger.info("Reconfiguring backend: \(oldHost) → \(newURL.host() ?? "")")

        baseURL = newURL
        tokenStore.clear()
        revision = UUID()
        configLock.unlock()

        // Persist the preference
        UserDefaults.standard.set(newURL.absoluteString, forKey: "serverBaseURL")
        NotificationCenter.default.post(name: .serverSessionDidChange, object: self)
    }

    /// Reset to production default and clear the stored override.
    func resetToProduction() {
        let productionURL = URL(string: ServerEnvironment.production.rawValue)!
        configLock.lock()

        baseURL = productionURL
        tokenStore.clear()
        revision = UUID()
        configLock.unlock()
        UserDefaults.standard.removeObject(forKey: "serverBaseURL")
        logger.info("Reset to production backend")
        NotificationCenter.default.post(name: .serverSessionDidChange, object: self)
    }

    /// Fetch the current user profile (Bearer-token authenticated).
    func fetchCurrentUser() async throws -> ServerUser? {
        guard isAuthenticated else { return nil }
        return try await request(.me)
    }

    // MARK: - Convenience: Academic Data

    func fetchCurrentSemester() async throws -> ServerSemester {
        try await request(.currentSemester)
    }

    func fetchSemesters(page: Int? = nil, pageSize: Int? = nil) async throws -> PaginatedResponse<ServerSemester> {
        try await request(.listSemesters(page: page, pageSize: pageSize))
    }

    func searchCourses(query: String? = nil, educationLevelId: Int? = nil, page: Int? = nil, pageSize: Int? = nil) async throws -> PaginatedResponse<ServerCourseSummary> {
        try await request(.listCourses(query: query, educationLevelId: educationLevelId, page: page, pageSize: pageSize))
    }

    func fetchCourseDetail(jwId: String) async throws -> ServerCourseDetail {
        try await request(.getCourse(jwId: jwId))
    }

    func searchSections(
        query: String? = nil, semesterId: Int? = nil, courseId: Int? = nil, teacherId: Int? = nil,
        page: Int? = nil, pageSize: Int? = nil
    ) async throws -> PaginatedResponse<ServerSectionSummary> {
        try await request(.listSections(query: query, semesterId: semesterId, courseId: courseId, teacherId: teacherId, page: page, pageSize: pageSize))
    }

    func fetchSectionDetail(jwId: String) async throws -> ServerSectionDetail {
        try await request(.getSection(jwId: jwId))
    }

    func fetchSectionSchedules(jwId: String) async throws -> [ServerScheduleEntry] {
        try await request(.getSectionSchedules(jwId: jwId))
    }

    func searchTeachers(query: String? = nil, page: Int? = nil, pageSize: Int? = nil) async throws -> PaginatedResponse<ServerTeacherSummary> {
        try await request(.listTeachers(query: query, page: page, pageSize: pageSize))
    }

    func fetchTeacherDetail(id: Int) async throws -> ServerTeacherDetail {
        try await request(.getTeacher(id: id))
    }

    func querySchedules(
        sectionId: Int? = nil, teacherId: Int? = nil,
        roomId: Int? = nil, dateFrom: String? = nil, dateTo: String? = nil, weekday: Int? = nil,
        sectionJwId: Int? = nil, sectionCode: String? = nil, teacherCode: String? = nil, roomJwId: Int? = nil,
        page: Int? = nil, pageSize: Int? = nil, locale: String? = nil
    ) async throws -> PaginatedResponse<ServerScheduleEntry> {
        try await request(.querySchedules(
            sectionId: sectionId, teacherId: teacherId, roomId: roomId,
            dateFrom: dateFrom, dateTo: dateTo, weekday: weekday,
            sectionJwId: sectionJwId, sectionCode: sectionCode, teacherCode: teacherCode, roomJwId: roomJwId,
            page: page, pageSize: pageSize, locale: locale
        ))
    }

    func importSubscriptions(codes: [String], semesterId: Int? = nil) async throws -> ImportSubscriptionsResponse {
        try await request(.importSubscriptions(MatchCodesRequest(codes: codes, semesterId: semesterId)))
    }

    // MARK: - Convenience: Homework

    func fetchHomeworks(sectionId: Int? = nil, page: Int? = nil, pageSize: Int? = nil) async throws -> ServerHomeworkListResponse {
        try await request(.listHomeworks(sectionId: sectionId, page: page, pageSize: pageSize))
    }

    func fetchSubscribedHomeworks(page: Int? = nil, pageSize: Int? = nil) async throws -> PaginatedResponse<ServerHomework> {
        try await request(.listSubscribedHomeworks(page: page, pageSize: pageSize))
    }

    func fetchHomework(id: String) async throws -> ServerHomework {
        let response: ServerHomeworkDetailResponse = try await request(.getHomework(id: id))
        return response.homework
    }

    // MARK: - Convenience: Todos

    func fetchTodos() async throws -> ServerTodoListResponse {
        try await request(.listTodos)
    }

    // MARK: - Convenience: Bus

    func fetchBusSchedule(versionKey: String? = nil) async throws -> ServerBusResponse {
        try await request(.busSchedule(versionKey: versionKey))
    }
}
