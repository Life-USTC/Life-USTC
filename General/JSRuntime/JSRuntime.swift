//
//  JSRuntime.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-05-08.
//

import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    var wkWebView: WKWebView

    func makeUIView(context _: Context) -> WKWebView { wkWebView }

    func updateUIView(_: WKWebView, context _: Context) {}
}

// Network Bridge to override CORS behaviors,
// The url format is: lu-bridge://proxy?url=ENCODED_URL&method=METHOD
class LUNetworkBridge: NSObject, WKURLSchemeHandler {
    func webView(_: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let originalURL = urlSchemeTask.request.url else { return }
        print(originalURL.absoluteString)
        let components = URLComponents(
            url: originalURL,
            resolvingAgainstBaseURL: false
        )!
        let queryItems = components.queryItems!
        let url = queryItems.first(where: { $0.name == "url" })!.value!
        let method = queryItems.first(where: { $0.name == "method" })!.value!
        let request = URLRequest(url: URL(string: url)!)
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            let response = HTTPURLResponse(
                url: urlSchemeTask.request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data!)
            urlSchemeTask.didFinish()
        }
        task.resume()

        print(url, method)
    }

    func webView(_: WKWebView, stop _: WKURLSchemeTask) {}
}

class LUJSRuntime {
    static let shared = LUJSRuntime()
    let wkWebView: WKWebView

    class LoggingMessageHandler: NSObject, WKScriptMessageHandler {
        func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) { print(message.body) }
    }

    init() {
        // load script with name console.js
        let overrideConsole = try! String(
            contentsOf: Bundle.main.url(
                forResource: "console",
                withExtension: "js"
            )!
        )
        let script = WKUserScript(
            source: overrideConsole,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        //        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        config.userContentController.addUserScript(script)
        config.userContentController.add(
            LoggingMessageHandler(),
            name: "logging"
        )
        config.setURLSchemeHandler(LUNetworkBridge(), forURLScheme: "lu-bridge")

        wkWebView = WKWebView(frame: .zero, configuration: config)
        wkWebView.evaluateJavaScript(overrideConsole)

        let url = Bundle.main.url(
            forResource: "Runtime",
            withExtension: "html"
        )!
        wkWebView.loadFileURL(url, allowingReadAccessTo: url)
        let request = URLRequest(url: url)
        wkWebView.load(request)

        wkWebView.evaluateJavaScript(
            """
            // console.log("Init finished here");
            """
        )
    }
}

struct LUJS_Runtime_Preview: PreviewProvider {
    static var previews: some View {
        WebView(wkWebView: LUJSRuntime.shared.wkWebView)
    }
}
