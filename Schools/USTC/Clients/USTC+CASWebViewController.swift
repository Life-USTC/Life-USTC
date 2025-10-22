//
//  USTC+CASWebViewController.swift
//  Life@USTC
//
//  Created by TianKai Ma on 10/8/25.
//

import WebKit

class CASWebViewController: UIViewController, WKNavigationDelegate {
    @AppSecureStorage("passportUsername") private var username: String
    @AppSecureStorage("passportPassword") private var password: String
    @LoginClient(.ustcCAS) private var casClient: UstcCasClient

    private var webView: WKWebView!
    var onLoginSuccess: (() -> Void)?
    var shouldAutoLogin: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        // Clear login status before attempting login
        _casClient.clearLoginStatus()

        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "formSubmit")
        config.userContentController = contentController

        // Clear cookies before loading the login page
        let websiteDataStore = WKWebsiteDataStore.default()
        let dataTypes = Set([WKWebsiteDataTypeCookies])
        websiteDataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            let ustcRecords = records.filter { record in
                record.displayName.contains("ustc.edu.cn")
            }
            websiteDataStore.removeData(ofTypes: dataTypes, for: ustcRecords) {
                // Also clear HTTPCookieStorage
                if let cookies = HTTPCookieStorage.shared.cookies {
                    for cookie in cookies where cookie.domain.contains("ustc.edu.cn") {
                        HTTPCookieStorage.shared.deleteCookie(cookie)
                    }
                }
            }
        }

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

    private var formSubmitted = false
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            let urlString = url.absoluteString
            
            // Check for successful login
            if urlString.hasPrefix("https://id.ustc.edu.cn/gate/cas-success") {
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
            
            // Check for failed login - detect if we're redirected back to login page after form submission
            // This typically happens when credentials are incorrect
            if formSubmitted {
                // If form was submitted but we're still on login/authserver page, it's a failure
                if urlString.contains("id.ustc.edu.cn") && !urlString.contains("/gate/cas-success") {
                    // Check specifically for error indicators
                    if urlString.contains("error") || urlString.contains("authserver/login") {
                        UstcCasClient.shared.loginFailed()
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
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
                    const usernameInput = document.querySelector('input[id="nameInput"]');
                    const passwordInput = document.querySelector('input[type="password"]');
                    const submitBtn = document.querySelector('button[id="submitBtn"]');

                    document.querySelector('input[id="nameInput"]').value = '\(username.replacingOccurrences(of: "'", with: "\\'"))';
                    document.querySelector('input[type="password"]').value = '\(password.replacingOccurrences(of: "'", with: "\\'"))';

                    if (!(usernameInput && passwordInput && submitBtn)) {
                        setTimeout(fillForm, 1000);
                        return;
                    }

                    usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
                    usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
                    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
                    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));

                    submitBtn.addEventListener('click', function(e) {
                        const usernameValue = document.querySelector('input[id="nameInput"]').value;
                        const passwordValue = document.querySelector('input[type="password"]').value;
                        window.webkit.messageHandlers.formSubmit.postMessage({
                            username: usernameValue,
                            password: passwordValue,
                            submitted: true
                        });
                    });

                    // Auto-submit if enabled
                    if (\(shouldAutoLogin ? "true" : "false")) {
                        setTimeout(function() {
                            submitBtn.click();
                        }, 500);
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
            let body = message.body as? [String: Any],
            let usernameValue = body["username"] as? String,
            let passwordValue = body["password"] as? String
        {
            // Store the credentials before form submission
            username = usernameValue
            password = passwordValue
            
            // Mark that form has been submitted to track login attempts
            if body["submitted"] as? Bool == true {
                formSubmitted = true
            }
            
            debugPrint("Credentials stored before form submission")
        }
    }
}
