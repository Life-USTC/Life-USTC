//
//  ServerAuth.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

private let logger = AppLogger.logger(for: "ServerAuth")

// MARK: - OAuth2 PKCE Authentication

/// Handles OAuth2 PKCE authentication against the Life@USTC server.
final class ServerAuth: NSObject, ASWebAuthenticationPresentationContextProviding,
    @unchecked Sendable
{
    static let shared = ServerAuth()

    static let clientID = "life-ustc-ios"
    static let redirectURI = "dev.tiankaima.life-ustc://auth/callback"
    static let callbackScheme = "dev.tiankaima.life-ustc"

    /// Always read the current client — don't cache, since backend can change.
    private var client: ServerClient { ServerClient.shared }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    // MARK: - Login

    @MainActor
    func login() async throws {
        let codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(
            url: client.baseURL.appendingPathComponent(
                "api/auth/oauth2/authorize"),
            resolvingAgainstBaseURL: false
        )!
        let resource = client.baseURL.absoluteString
        components.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "scope", value: "openid profile email offline_access"),
            .init(name: "resource", value: resource),
        ]

        let authURL = components.url!
        logger.info("Starting OAuth2 PKCE flow → \(authURL.host() ?? "")")

        let code = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String, Error>) in

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                    let components = URLComponents(
                        url: callbackURL, resolvingAgainstBaseURL: false),
                    let code = components.queryItems?.first(where: {
                        $0.name == "code"
                    })?.value
                else {
                    continuation.resume(throwing: ServerError.notAuthenticated)
                    return
                }
                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        logger.info("Got authorization code, exchanging for tokens")
        try await exchangeCodeForTokens(
            code: code, codeVerifier: codeVerifier
        )
    }

    // MARK: - Logout

    func logout() {
        logger.info("Logging out, clearing tokens")
        client.clearTokens()
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(
        code: String, codeVerifier: String
    ) async throws {
        let url = client.baseURL.appendingPathComponent(
            "api/auth/oauth2/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let bodyParams: [(String, String)] = [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", Self.redirectURI),
            ("client_id", Self.clientID),
            ("code_verifier", codeVerifier),
            ("resource", client.baseURL.absoluteString),
        ]

        request.httpBody = bodyParams
            .map { key, value in
                let encoded =
                    value.addingPercentEncoding(
                        withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let body = String(data: data, encoding: .utf8) {
                logger.error("Token exchange failed (\(status)): <redacted>")
            }
            throw ServerError.notAuthenticated
        }

        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(
            OAuthTokenResponse.self, from: data
        )
        client.accessToken = tokenResponse.accessToken
        if let refresh = tokenResponse.refreshToken {
            client.refreshToken = refresh
        }
        logger.info(
            "Token exchange succeeded (has refresh: \(tokenResponse.refreshToken != nil))"
        )
    }

    // MARK: - PKCE Helpers

    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded
    }
}

// MARK: - Base64URL Encoding

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
