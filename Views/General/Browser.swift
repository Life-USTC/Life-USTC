//
//  Browser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI
import WebKit

struct SwiftUIWebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    let webView: WKWebView
    var url: URL

    init(url: URL) {
        self.url = url
        let wkWebConfig = WKWebViewConfiguration()
        for cookie in URLSession.shared.configuration.httpCookieStorage?.cookies ?? [] {
            wkWebConfig.websiteDataStore.httpCookieStore.setCookie(cookie)
        }
        wkWebConfig.defaultWebpagePreferences.preferredContentMode = .mobile
        wkWebConfig.upgradeKnownHostsToHTTPS = true
        webView = WKWebView(frame: .zero, configuration: wkWebConfig)
        // identify self as mobile client, so that the website will render the mobile version
        webView.customUserAgent = userAgent
    }

    func makeUIView(context _: Context) -> WKWebView {
        webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        webView.load(URLRequest(url: url))
    }
}

struct Browser: View {
    var url: URL
    var title: String = "Detail"

    var body: some View {
        SwiftUIWebView(url: url)
            .padding([.leading, .trailing], 2)
            .toolbar {
                ShareLink(item: self.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .navigationBarTitle(title, displayMode: .inline)
    }
}
