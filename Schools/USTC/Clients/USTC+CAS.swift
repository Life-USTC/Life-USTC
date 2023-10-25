//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Foundation
import UIKit
import Vision

private let ustcCasUrl = URL(string: "https://passport.ustc.edu.cn")!
private let ustcLoginUrl = URL(string: "https://passport.ustc.edu.cn/login")!

/// A cas client to login to https://passport.ustc.edu.cn/
class UstcCasClient: LoginClientProtocol {
    static let shared = UstcCasClient()

    @AppSecureStorage("passportUsername") private var username: String
    @AppSecureStorage("passportPassword") private var password: String

    var precheckFails: Bool { username.isEmpty || password.isEmpty }
    var session: URLSession = .shared

    func getLtTokenFromCAS(
        url: URL = ustcLoginUrl
    ) async throws -> (
        ltToken: String,
        cookie: [HTTPCookie],
        captacha: String
    ) {
        let findLtStringRegex = try! Regex("LT-[0-9a-z]+")

        // loading the LT-Token requires a non-logined status
        // using a ephemeral session would achieve this.
        let session = URLSession(configuration: .ephemeral)
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)

        guard let dataString = String(data: data, encoding: .utf8),
              let match = dataString.firstMatch(of: findLtStringRegex)
        else {
            throw BaseError.runtimeError("Failed to fetch raw LT-Token")
        }

        let captchaCode = try await getCaptchaCodeFromCAS(session: session)

        return (
            String(match.0),
            session.configuration.httpCookieStorage?.cookies ?? [],
            captchaCode
        )
    }


    func getCaptchaCodeFromCAS(session: URLSession) async throws -> String {
        let capatchaURL = URL(string: "https://passport.ustc.edu.cn/validatecode.jsp?type=login")!

        var request = URLRequest(url: capatchaURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)

        guard let cgImage = UIImage(data: data)?.cgImage else {
            throw BaseError.runtimeError("Failed to fetch captcha code")
        }

        return try await withCheckedThrowingContinuation { continuation in
            func recognizeTextHandler(request: VNRequest, error: Error?) {
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                let recognizedStrings = observations.compactMap { observation in
                    return observation.topCandidates(1).first?.string
                }.joined()
                continuation.resume(returning: recognizedStrings)
            }

            let vnrequestHandler = VNImageRequestHandler(cgImage: cgImage)
            let vnRequest = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)

            do {
                try vnrequestHandler.perform([vnRequest])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func loginToCAS(url: URL = ustcLoginUrl, service: URL? = nil) async throws
    -> Bool
    {
        if precheckFails { throw BaseError.runtimeError("Precheck fails") }
        let (ltToken, cookies, captchaCode) = try await getLtTokenFromCAS(url: url)

        let queries: [String: String] = [
            "model": "uplogin.jsp",
            "CAS_LT": ltToken,
            "service": service?.absoluteString ?? "",
            "warn": "",
            "showCode": "1",
            "qrcode": "",
            "username": username,
            "password": password,
            "LT": captchaCode,
            "button": "",
        ]

        var request = URLRequest(url: ustcLoginUrl)
        request.httpBody = queries.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&").data(using: .utf8)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = true
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        session.configuration.httpCookieStorage?
            .setCookies(cookies, for: ustcCasUrl, mainDocumentURL: ustcCasUrl)

        let _ = try await session.data(for: request)

        return session.configuration.httpCookieStorage?.cookies?
            .contains(where: { $0.name == "logins" || $0.name == "TGC" })
            ?? false
    }

    override func login() async throws -> Bool {
        try await loginToCAS()
    }

    override init() {}
}

extension LoginClientProtocol {
    static let ustcCAS = UstcCasClient.shared
}

extension URL {
    func ustcCASLoginMarkup() -> URL {
        CASLoginMarkup(casServer: ustcCasUrl)
    }
}
