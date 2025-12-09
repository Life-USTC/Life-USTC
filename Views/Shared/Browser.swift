//
//  Browser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Reeeed
import SwiftUI
import UIKit
import WebKit

struct BrowserUIKitView: UIViewControllerRepresentable {
    @Binding var url: URL
    @Binding var useReeed: Bool
    @Binding var reeedMode: ReeedEnabledMode

    // Closure used to open external URLs in an extension-safe way
    var openExternalURL: (URL) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator

        vc.view.addSubview(webView)

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        let guide = vc.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: guide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])

        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset

        webView.load(URLRequest(url: url))

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

final class Coordinator: NSObject, WKNavigationDelegate {
    private let parent: BrowserUIKitView
    init(_ parent: BrowserUIKitView) { self.parent = parent }

    @AppSecureStorage("passportUsername") var username: String
    @AppSecureStorage("passportPassword") var password: String

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        if ["http", "https"].contains(scheme) {
            if url.host == "id.ustc.edu.cn" && url.absoluteString.hasPrefix("https://id.ustc.edu.cn/gate/cas-success") {
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    HTTPCookieStorage.shared.setCookies(
                        cookies,
                        for: URL(string: "https://id.ustc.edu.cn"),
                        mainDocumentURL: nil
                    )
                    USTCCASClient.shared.loginSuccess()
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }

        // For non-http(s) schemes, ask the SwiftUI host to open the URL in an extension-safe way
        parent.openExternalURL(url)
        decisionHandler(.cancel)
        return
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url else { return }
        if currentURL.host == "id.ustc.edu.cn" && currentURL.path.hasPrefix("/cas/login") {
            injectCASCredentials(into: webView)
        }
    }

    func injectCASCredentials(into webView: WKWebView) {
        let escapedUsername = username.replacingOccurrences(of: "'", with: "\\'")
        let escapedPassword = password.replacingOccurrences(of: "'", with: "\\'")
        let script = """
            (function() {
                function fillForm() {
                    const usernameInput = document.querySelector('input[id="nameInput"]') || document.querySelector('input[name="username"], input[name="user"]');
                    const passwordInput = document.querySelector('input[type="password"]');
                    const submitBtn = document.querySelector('button[id="submitBtn"], button[type="submit"], input[type="submit"]');

                    if (!(usernameInput && passwordInput)) {
                        setTimeout(fillForm, 500);
                        return;
                    }

                    usernameInput.value = '\(escapedUsername)';
                    passwordInput.value = '\(escapedPassword)';

                    usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
                    usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
                    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
                    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));

                    (function() {
                        if (document.getElementById('life-ustc-autofill-banner')) return;
                        const banner = document.createElement('div');
                        banner.id = 'life-ustc-autofill-banner';
                        banner.textContent = 'Life@USTC Autofill Active';
                        banner.setAttribute('role', 'status');
                        banner.style.background = '#0B7285';
                        banner.style.color = 'white';
                        banner.style.fontFamily = 'system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif';
                        banner.style.fontSize = '12px';
                        banner.style.padding = '6px 10px';
                        banner.style.borderRadius = '6px';
                        banner.style.display = 'inline-block';
                        banner.style.margin = '8px 0';
                        const container = (usernameInput && usernameInput.closest('form')) || document.querySelector('form') || document.body;
                        container.prepend(banner);
                    })();

                    if (!window.LIFE_USTC_AUTOSUBMIT_TRIGGERED && usernameInput.value && passwordInput.value) {
                        window.LIFE_USTC_AUTOSUBMIT_TRIGGERED = true;
                        const formEl = (usernameInput && usernameInput.closest('form')) || document.querySelector('form');
                        setTimeout(function() {
                            if (submitBtn) {
                                submitBtn.click();
                            } else if (formEl && typeof formEl.requestSubmit === 'function') {
                                formEl.requestSubmit();
                            } else if (formEl) {
                                formEl.submit();
                            }
                        }, 200);
                    }
                }

                if (document.readyState === 'complete') {
                    setTimeout(fillForm, 300);
                } else {
                    window.addEventListener('load', function() { setTimeout(fillForm, 300); });
                }
            })();
            """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

struct Browser: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    @State var useReeed = false
    @State var prepared = false
    @State var reeedMode: ReeedEnabledMode = .never
    @State var url: URL

    var title: LocalizedStringKey = "Detail"

    var contentView: some View {
        Group {
            if useReeed {
                ReeeederView(url: url, options: .init(includeExitReaderButton: false), useReeeder: $useReeed)
            } else {
                BrowserUIKitView(
                    url: $url,
                    useReeed: $useReeed,
                    reeedMode: $reeedMode,
                    openExternalURL: { url in
                        openURL(url)
                    }
                )
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .if(!prepared) { _ in
            ProgressView()
        }
    }

    var body: some View {
        contentView
            .id(url)
            .toolbar(.hidden, for: .tabBar)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if reeedMode == .userDefined {
                    Button {
                        useReeed.toggle()
                    } label: {
                        Label(
                            useReeed ? "Exit Reeeder" : "Reeeder",
                            systemImage: useReeed ? "doc.plaintext.fill" : "doc.plaintext"
                        )
                    }
                }
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .task {
                if !prepared {
                    do {
                        reeedMode = SchoolSystem.current.reeedEnabledMode(url)

                        if reeedMode == .always {
                            useReeed = true
                        }

                        try await SchoolSystem.current.setCookiesBeforeWebView?(url)
                    } catch {
                        debugPrint(error)
                    }
                    prepared = true
                }
            }
    }
}
