//
//  ServerClient.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation
import KeychainAccess

private let logger = AppLogger.logger(for: "ServerClient")

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

    /// Resolve baseURL from user preference → Info.plist → production default.
    static var resolvedBaseURL: URL {
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
        var urlRequest = endpoint.buildURLRequest(baseURL: baseURL)

        if !accessToken.isEmpty {
            urlRequest.setValue(
                "Bearer \(accessToken)",
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
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw ServerError.networkError(error)
        }

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
                if data.count < 500, let body = String(data: data, encoding: .utf8) {
                    logger.debug("Response body: \(body)")
                }
                throw ServerError.decodingError(error)
            }
        case 401:
            if retry, !refreshToken.isEmpty {
                logger.info("Got 401, attempting token refresh")
                try await refreshAccessToken()
                return try await request(endpoint, retry: false)
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

    private func refreshAccessToken() async throws {
        let url = baseURL.appendingPathComponent("api/auth/oauth2/token")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let bodyParams: [(String, String)] = [
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", ServerAuth.clientID),
        ]
        urlRequest.httpBody = Self.formEncode(bodyParams)

        logger.info("Refreshing access token")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            logger.error("Token refresh failed (\(status)): \(body)")
            clearTokens()
            throw ServerError.notAuthenticated
        }

        let tokenResponse = try decoder.decode(OAuthTokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        if let newRefresh = tokenResponse.refreshToken {
            refreshToken = newRefresh
        }
        logger.info("Token refresh succeeded")
    }

    // MARK: - Session

    func clearTokens() {
        logger.info("Clearing stored tokens")
        tokenStore.clear()
    }

    /// Atomically switch the backend URL. Clears tokens since they belong to the old server.
    func reconfigure(baseURL newURL: URL) {
        configLock.lock()
        defer { configLock.unlock() }

        let oldHost = baseURL.host() ?? ""
        logger.info("Reconfiguring backend: \(oldHost) → \(newURL.host() ?? "")")

        baseURL = newURL
        clearTokens()

        // Persist the preference
        UserDefaults.standard.set(newURL.absoluteString, forKey: "serverBaseURL")
    }

    /// Reset to production default and clear the stored override.
    func resetToProduction() {
        let productionURL = URL(string: ServerEnvironment.production.rawValue)!
        configLock.lock()
        defer { configLock.unlock() }

        baseURL = productionURL
        clearTokens()
        UserDefaults.standard.removeObject(forKey: "serverBaseURL")
        logger.info("Reset to production backend")
    }

    /// Fetch the current user profile via `/api/me` (Bearer-token authenticated).
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

    func searchCourses(query: String? = nil, page: Int? = nil, pageSize: Int? = nil) async throws -> PaginatedResponse<ServerCourseSummary> {
        try await request(.listCourses(query: query, page: page, pageSize: pageSize))
    }

    func fetchCourseDetail(jwId: String) async throws -> ServerCourseDetail {
        try await request(.getCourse(jwId: jwId))
    }

    func searchSections(
        query: String? = nil, semesterId: Int? = nil, courseId: Int? = nil,
        page: Int? = nil, pageSize: Int? = nil
    ) async throws -> PaginatedResponse<ServerSectionSummary> {
        try await request(.listSections(query: query, semesterId: semesterId, courseId: courseId, page: page, pageSize: pageSize))
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
        room: String? = nil, date: String? = nil, weekday: Int? = nil
    ) async throws -> PaginatedResponse<ServerScheduleEntry> {
        try await request(.querySchedules(sectionId: sectionId, teacherId: teacherId, room: room, date: date, weekday: weekday))
    }

    // MARK: - Convenience: Homework

    func fetchHomeworks(sectionId: Int? = nil, subscribedOnly: Bool? = nil) async throws -> ServerHomeworkListResponse {
        try await request(.listHomeworks(sectionId: sectionId, subscribedOnly: subscribedOnly))
    }

    func fetchHomework(id: String) async throws -> ServerHomework {
        try await request(.getHomework(id: id))
    }

    // MARK: - Convenience: Todos

    func fetchTodos() async throws -> ServerTodoListResponse {
        try await request(.listTodos)
    }

    // MARK: - Convenience: Bus

    func fetchBusSchedule(
        originCampusId: Int? = nil, destinationCampusId: Int? = nil,
        dayType: String? = nil, limit: Int? = nil
    ) async throws -> ServerBusResponse {
        try await request(.busSchedule(originCampusId: originCampusId, destinationCampusId: destinationCampusId, dayType: dayType, limit: limit))
    }
}
