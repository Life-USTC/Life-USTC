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

    var session: URLSession = .shared

    var loginContinuation: CheckedContinuation<Bool, Error>?
    var loginWebViewController: UIViewController?

    override func login() async throws -> Bool {
        return try await login(shouldAutoLogin: true)
    }

    func login(
        shouldAutoLogin: Bool = false,
        username: String? = nil,
        password: String? = nil
    ) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            Task.detached { @MainActor in
                self.presentLoginWebView(
                    shouldAutoLogin: shouldAutoLogin,
                    username: username,
                    password: password
                )
            }
        }
    }

    @MainActor
    func presentLoginWebView(
        shouldAutoLogin: Bool = false,
        username: String? = nil,
        password: String? = nil
    ) {
        let hosting = UIHostingController(
            rootView: Browser(
                useReeed: false,
                prepared: true,
                reeedMode: .userDefined,
                url: URL(string: "https://id.ustc.edu.cn/cas/login")!,
                title: LocalizedStringKey("CAS Login")
            )
        )
        let navigationController = UINavigationController(rootViewController: hosting)
        navigationController.modalPresentationStyle = .fullScreen

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        guard var topController = keyWindow?.rootViewController else { return }
        while let presented = topController.presentedViewController { topController = presented }
        if let nav = topController as? UINavigationController { topController = nav.visibleViewController ?? nav }
        if let tab = topController as? UITabBarController { topController = tab.selectedViewController ?? tab }

        topController.present(navigationController, animated: true)

        loginWebViewController = navigationController
    }

    func dismissLoginWebView() {
        loginWebViewController?.dismiss(animated: true)
        loginWebViewController = nil
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
