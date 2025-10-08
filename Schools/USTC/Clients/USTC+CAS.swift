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

class CASWebViewController: UIViewController, WKNavigationDelegate {
    @AppSecureStorage("passportUsername") private var username: String
    @AppSecureStorage("passportPassword") private var password: String

    private var webView: WKWebView!
    var onLoginSuccess: (() -> Void)?
    var shouldAutoLogin: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "formSubmit")
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        } else {
        }
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        webView.load(URLRequest(url: URL(string: "https://id.ustc.edu.cn/")!))

        let fillButton = UIBarButtonItem(
            title: "Fill",
            style: .plain,
            target: self,
            action: #selector(manualFillForm)
        )
        fillButton.accessibilityLabel = "Fill credentials"
        fillButton.image = UIImage(systemName: "rectangle.and.pencil.and.ellipsis")
        navigationItem.leftBarButtonItem = fillButton
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelLogin)
        )
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
            url.absoluteString.hasPrefix("https://id.ustc.edu.cn/gate/cas-success")
        {
            // Success! Extract cookies and notify client
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                HTTPCookieStorage.shared.setCookies(
                    cookies,
                    for: URL(string: "https://id.ustc.edu.cn"),
                    mainDocumentURL: nil
                )
                UstcCasClient.shared.loginSuccess()
                self.onLoginSuccess?()
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject username and password after page loads
        Task {
            await injectCredentials()
        }
    }

    private func injectCredentials() async {
        try? await Task.sleep(nanoseconds: 500_000_000)

        let combinedScript = """
            (function() {
                if (document.readyState === 'complete') {
                    setTimeout(fillForm, 1000);
                } else {
                    window.addEventListener('load', setTimeout(fillForm, 1000));
                }

                function fillForm() {
                    document.querySelector('input[id="nameInput"]').value = '\(username.replacingOccurrences(of: "'", with: "\\'"))';
                    document.querySelector('input[type="password"]').value = '\(password.replacingOccurrences(of: "'", with: "\\'"))';

                    const usernameInput = document.querySelector('input[id="nameInput"]');
                    const passwordInput = document.querySelector('input[type="password"]');
                    if (usernameInput && passwordInput) {
                        usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
                        usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
                        passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
                        passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
                    } else {
                        setTimeout(fillForm, 500);
                        return
                    }

                    const submitBtn = document.querySelector('button[id="submitBtn"]');
                    if (submitBtn) {
                        submitBtn.addEventListener('click', function(e) {
                            const usernameValue = document.querySelector('input[id="nameInput"]').value;
                            const passwordValue = document.querySelector('input[type="password"]').value;
                            window.webkit.messageHandlers.formSubmit.postMessage({
                                username: usernameValue,
                                password: passwordValue
                            });
                        });

                        // Auto-submit if enabled
                        if (\(shouldAutoLogin ? "true" : "false")) {
                            setTimeout(function() {
                                submitBtn.click();
                            }, 500);
                        }
                    }
                }
            })();
            """

        _ = try? await webView.evaluateJavaScript(combinedScript)
    }

    @objc private func manualFillForm() {
        Task {
            await injectCredentials()
        }
    }

    @objc private func cancelLogin() {
        UstcCasClient.shared.loginFailed()
    }
}

extension CASWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "formSubmit",
            let body = message.body as? [String: String],
            let usernameValue = body["username"],
            let passwordValue = body["password"]
        {
            // Store the credentials before form submission
            self.username = usernameValue
            self.password = passwordValue
            debugPrint("Credentials stored before form submission")
        }
    }
}

extension URL {
    func ustcCASLoginMarkup() -> URL {
        // https://passport.ustc.edu.cn is the old url used for redirecting
        // owing to the fact that many system still uses this endpoint, we still mark with this url
        CASLoginMarkup(casServer: URL(string: "https://passport.ustc.edu.cn")!)
    }
}
