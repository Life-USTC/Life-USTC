//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI
import UIKit

class UstcCasClient: LoginClientProtocol {
    static let shared = UstcCasClient()

    @AppStorage("widgetCanRefreshNewData", store: .appGroup) var _widgetCanRefreshNewData: Bool? = nil

    var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private var loginContinuation: CheckedContinuation<Bool, Error>?
    private var loginWebViewController: UIViewController?
    private weak var presenterViewController: UIViewController?

    // Default login keeps previous behavior for API compatibility but requires presenter to be set beforehand.
    override func login() async throws -> Bool {
        guard let presenterViewController else {
            throw BaseError.runtimeError("Login presenter not set. Call login(presentingFrom:) from UI.")
        }
        return try await login(presentingFrom: presenterViewController, shouldAutoLogin: true)
    }

    // New API that accepts a presenter VC, suitable for app extensions and clearer control from UI layer.
    func login(presentingFrom presenterViewController: UIViewController, shouldAutoLogin: Bool = false) async throws
        -> Bool
    {
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            Task.detached { @MainActor in
                self.presentLoginWebView(presentingFrom: presenterViewController, shouldAutoLogin: shouldAutoLogin)
            }
        }
    }

    // Allow UI to inject a presenter ahead of time so requireLogin()->login() can work
    func setPresenter(_ presenter: UIViewController) {
        self.presenterViewController = presenter
    }

    @MainActor private func presentLoginWebView(
        presentingFrom presenterViewController: UIViewController,
        shouldAutoLogin: Bool = false
    ) {
        let webViewController = CASWebViewController()
        webViewController.shouldAutoLogin = shouldAutoLogin

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.modalPresentationStyle = .fullScreen

        // Find the topmost presented view controller to ensure presentation works
        var topController = presenterViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        topController.present(navigationController, animated: true)

        loginWebViewController = navigationController
    }

    @available(*, deprecated, message: "Request these URLs yourself")
    func loginToCAS(_ url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)

        guard let redirectURL = response.url else {
            throw BaseError.runtimeError("No redirect URL after CAS login.")
        }

        debugPrint(session.configuration.httpCookieStorage!.cookies.map({ $0.map { "\($0.name) = \($0.value)" } })!)

        // Follow redirect to service URL
        var serviceRequest = URLRequest(url: redirectURL)
        serviceRequest.httpMethod = "GET"
        serviceRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        _ = try await session.data(for: serviceRequest)
    }

    func loginSuccess() {
        loginContinuation?.resume(returning: true)
        loginContinuation = nil
        dismissLoginWebView()
    }

    func loginFailed() {
        loginContinuation?.resume(returning: false)
        loginContinuation = nil
        dismissLoginWebView()
    }

    private func dismissLoginWebView() {
        loginWebViewController?.dismiss(animated: true)
        loginWebViewController = nil
    }
}

extension LoginClientProtocol {
    static let ustcCAS = UstcCasClient.shared
}

extension URL {
    func ustcCASLoginMarkup() -> URL {
        // https://passport.ustc.edu.cn is the old url used for redirecting
        // owing to the fact that many system still uses this endpoint, we still mark with this url
        CASLoginMarkup(casServer: URL(string: "https://passport.ustc.edu.cn")!)
    }
}
