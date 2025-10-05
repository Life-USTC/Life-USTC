//
//  Browser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Reeeed
import SwiftUI
import WebKit

struct SwiftUIWebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    let webView: WKWebView
    var url: URL

    init(url: URL) {
        self.url = url
        let wkWebConfig = WKWebViewConfiguration()
        wkWebConfig.defaultWebpagePreferences.preferredContentMode = .mobile
        wkWebConfig.upgradeKnownHostsToHTTPS = true
        webView = WKWebView(frame: .zero, configuration: wkWebConfig)
        // identify self as mobile client, so that the website will render the mobile version
        webView.customUserAgent = userAgent
        updateCookies()
    }

    func updateCookies() {
        for cookie in URLSession.shared.configuration.httpCookieStorage?.cookies ?? [] {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }

    func makeUIView(context _: Context) -> WKWebView { webView }

    func updateUIView(_: WKWebView, context _: Context) {
        webView.load(URLRequest(url: url))
    }
}

struct Browser: View {
    @State var useReeed = false
    @State var isCookiesReady = false
    var url: URL
    var title: String = "Detail"
    var webView: SwiftUIWebView

    var body: some View {
        Group {
            if isCookiesReady {
                if useReeed {
                    ReeeederView(url: url)
                } else {
                    webView
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .padding([.leading, .trailing], 2)
        .toolbar {
            Button {
                useReeed.toggle()
            } label: {
                Label(
                    "Reeed",
                    systemImage: useReeed
                        ? "doc.plaintext.fill" : "doc.plaintext"
                )
            }
            ShareLink(item: self.url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .id(url)
        .task {
            // Set cookies before allowing web view to load
            if !isCookiesReady {
                do {
                    if let setCookiesBeforeWebView = SchoolExport.shared.setCookiesBeforeWebView {
                        try await setCookiesBeforeWebView()
                    }
                } catch {
                    debugPrint(error)
                }
                webView.updateCookies()
                isCookiesReady = true
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    init(url _url: URL, title: String = "Detail") {
        self.url = _url
        self.title = title
        self.webView = SwiftUIWebView(url: _url)
    }
}
