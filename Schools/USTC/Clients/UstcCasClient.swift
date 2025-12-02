//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI
import UIKit
import WebKit

class UstcCasClient: LoginClientProtocol {
    static let shared = UstcCasClient()

    @AppSecureStorage("passportUsername") var username: String
    @AppSecureStorage("passportPassword") var password: String

    var loginContinuation: CheckedContinuation<Bool, Error>?
    var loginWebViewController: UIViewController?
    private var hiddenHostingController: UIHostingController<Browser>?
    private var backgroundLoginCompleted = false
    private var hiddenHostView: UIView?

    override func login() async throws -> Bool {
        return try await login(shouldAutoLogin: true)
    }

    func login(
        shouldAutoLogin: Bool = true,
        username: String? = nil,
        password: String? = nil
    ) async throws -> Bool {
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                self.loginContinuation = continuation
                self.startBackgroundLogin()
                //                try? await Task.sleep(nanoseconds: 10_000_000_000)
                try? await Task.sleep(nanoseconds: 100_000_000)
                if !self.backgroundLoginCompleted {
                    self.presentLoginWebView(
                        shouldAutoLogin: shouldAutoLogin,
                        username: username,
                        password: password
                    )
                }
            }
        }
        return result
    }

    @MainActor
    func presentLoginWebView(
        shouldAutoLogin: Bool = true,
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

    private func startBackgroundLogin() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
        guard let window = keyWindow else { return }

        let browser = Browser(
            useReeed: false,
            prepared: true,
            reeedMode: .userDefined,
            url: URL(string: "https://id.ustc.edu.cn/cas/login")!,
            title: LocalizedStringKey("CAS Login")
        )
        let hosting = UIHostingController(rootView: browser)
        hosting.view.isUserInteractionEnabled = false
        hosting.view.alpha = 0.001
        hosting.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)

        let host = UIView(frame: hosting.view.frame)
        host.isUserInteractionEnabled = false
        host.alpha = 0.001
        window.addSubview(host)
        host.addSubview(hosting.view)
        hiddenHostingController = hosting
        hiddenHostView = host
    }

    func loginSuccess() {
        loginContinuation?.resume(returning: true)
        loginContinuation = nil
        dismissLoginWebView()
        backgroundLoginCompleted = true
        hiddenHostingController?.view.removeFromSuperview()
        hiddenHostingController = nil
        hiddenHostView?.removeFromSuperview()
        hiddenHostView = nil
    }

    func loginFailed() {
        loginContinuation?.resume(returning: false)
        loginContinuation = nil
        dismissLoginWebView()
        hiddenHostingController?.view.removeFromSuperview()
        hiddenHostingController = nil
        hiddenHostView?.removeFromSuperview()
        hiddenHostView = nil
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
