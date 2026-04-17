//
//  ServerClient.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation
import KeychainAccess
import os.log

private let logger = Logger(
    subsystem: "dev.tiankaima.Life-USTC",
    category: "ServerClient"
)

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

// MARK: - Server Client Configuration

struct ServerClientConfiguration {
    let baseURL: URL
    let session: URLSession
    var tokenStore: TokenStore

    /// Default configuration from Info.plist / environment.
    static var `default`: ServerClientConfiguration {
        let baseURL: URL = {
            if let override = Bundle.main.object(forInfoDictionaryKey: "ServerBaseURL") as? String,
               let url = URL(string: override)
            {
                logger.info("Using server URL from Info.plist: \(override, privacy: .public)")
                return url
            }
            return URL(string: "https://life-ustc.tiankaima.dev")!
        }()

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

    let baseURL: URL
    private let session: URLSession
    var tokenStore: TokenStore
    let decoder: JSONDecoder
    let encoder: JSONEncoder

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
            "\(urlRequest.httpMethod ?? "GET", privacy: .public) \(urlRequest.url?.absoluteString ?? "", privacy: .public)"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            throw ServerError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.networkError(URLError(.badServerResponse))
        }

        logger.debug(
            "← \(httpResponse.statusCode, privacy: .public) (\(data.count) bytes) \(urlRequest.url?.path ?? "", privacy: .public)"
        )

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error(
                    "Decode error for \(urlRequest.url?.path ?? "", privacy: .public): \(String(describing: error), privacy: .public)"
                )
                if let body = String(data: data.prefix(500), encoding: .utf8) {
                    logger.debug("Response body (truncated): \(body, privacy: .private)")
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
            logger.warning("Forbidden: \(errResp?.error ?? "unknown", privacy: .public)")
            throw ServerError.forbidden(errResp?.error ?? "Forbidden")
        case 400:
            let errResp = try? decoder.decode(ServerErrorResponse.self, from: data)
            logger.warning("Bad request: \(errResp?.error ?? "unknown", privacy: .public)")
            throw ServerError.badRequest(errResp?.error ?? "Bad request")
        case 404:
            throw ServerError.notFound
        default:
            let errResp = try? decoder.decode(ServerErrorResponse.self, from: data)
            let msg = errResp?.error ?? "Server error (\(httpResponse.statusCode))"
            logger.error("Server error \(httpResponse.statusCode, privacy: .public): \(msg, privacy: .public)")
            throw ServerError.serverError(msg)
        }
    }

    /// Fire a request that returns no meaningful body (e.g. DELETE).
    func requestVoid(_ endpoint: ServerEndpoint) async throws {
        let _: SuccessResponse = try await request(endpoint)
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

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": ServerAuth.clientID,
            "resource": baseURL.absoluteString,
        ]
        urlRequest.httpBody = bodyParams
            .map {
                "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        logger.info("Refreshing access token")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("Token refresh failed with status \(status, privacy: .public)")
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

    /// Fetch the current user profile via `/api/me` (Bearer-token authenticated).
    func fetchCurrentUser() async throws -> ServerUser? {
        guard isAuthenticated else { return nil }
        return try await request(.me)
    }
}
