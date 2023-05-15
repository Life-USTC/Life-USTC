//
//  JSRuntime.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-05-08.
//

import Foundation
import WebKit
import SwiftUI

struct WebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    var wkWebView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        wkWebView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

class LUJSRuntime {
    static let shared = LUJSRuntime()
    let wkWebView: WKWebView

    // run given script on self
    func run(script: String, completition: @escaping (Any) -> Void = {_ in}) {
        self.wkWebView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print(error)
            } else if let result = result {
                completition(result)
            }
        }
    }

    class LoggingMessageHandler: NSObject, WKScriptMessageHandler {
        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            print(message.body)
        }
    }

    init() {
        debugPrint("LUJSRuntime init")
        // load script with name console.jg
        let overrideConsole = try! String(contentsOf: Bundle.main.url(forResource: "console", withExtension: "js")!)
        let preferences = WKPreferences()
        preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        preferences.setValue(true, forKey: "developerExtrasEnabled")
        let config = WKWebViewConfiguration()
        config.preferences = preferences
        wkWebView = WKWebView(frame: .zero, configuration: config)

        wkWebView.configuration.userContentController.add(LoggingMessageHandler(), name: "logging")
        wkWebView.evaluateJavaScript(overrideConsole)

        wkWebView.load(URLRequest(url: URL(string: "https://www.example.com")!))
        self.run(script: "console.log('LUJSRuntime init finished, calling init')")
    }
}
