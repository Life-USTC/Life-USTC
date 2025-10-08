//
//  USTC+CASWebViewController.swift
//  学在科大
//
//  Created by TianKai Ma on 10/8/25.
//

import WebKit

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
