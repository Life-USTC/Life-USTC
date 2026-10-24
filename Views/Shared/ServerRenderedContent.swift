import SwiftUI
import WebKit

/// Displays the server's sanitized HTML while the surrounding native view owns scrolling and links.
struct ServerRenderedContent: View {
    let html: String
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var height: CGFloat = 1

    var body: some View {
        ServerRenderedWebView(html: html, fontSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                              height: $height, openURL: { openURL($0) })
            .frame(height: height)
            .id(dynamicTypeSize)
    }
}

private struct ServerRenderedWebView: UIViewRepresentable {
    let html: String
    let fontSize: CGFloat
    @Binding var height: CGFloat
    let openURL: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "contentHeight")
        controller.addUserScript(WKUserScript(source: """
        const reportHeight = () => window.webkit.messageHandlers.contentHeight.postMessage(
            Math.ceil(document.body.getBoundingClientRect().height));
        new ResizeObserver(reportHeight).observe(document.body);
        reportHeight();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.html != html else { return }
        context.coordinator.html = html
        view.loadHTMLString("""
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; background: transparent; }
        body { font: \(fontSize)px -apple-system; line-height: 1.5; overflow-wrap: anywhere; }
        body > :first-child { margin-top: 0; } body > :last-child { margin-bottom: 0; }
        a { color: -apple-system-blue; } img { max-width: 100%; height: auto; }
        figure { margin: 1em 0; } figcaption { font-size: .85em; color: GrayText; }
        pre { overflow-x: auto; padding: .75em; background: rgba(127,127,127,.12); border-radius: 6px; }
        blockquote { margin: 1em 0; padding-left: 1em; border-left: 3px solid GrayText; }
        table { display: block; max-width: 100%; overflow-x: auto; border-collapse: collapse; }
        th, td { border: 1px solid GrayText; padding: .4em .6em; }
        .katex-html { display: none; } .katex-display { display: block; overflow-x: auto; margin: 1em 0; }
        </style></head><body>\(html)</body></html>
        """, baseURL: ServerClient.shared.baseURL)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "contentHeight")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: ServerRenderedWebView
        var html: String?

        init(_ parent: ServerRenderedWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let value = message.body as? Double, value.isFinite, value >= 0 else { return }
            parent.height = max(1, CGFloat(value))
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                parent.openURL(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
