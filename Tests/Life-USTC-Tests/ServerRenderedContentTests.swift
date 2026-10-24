import SwiftUI
import WebKit
import XCTest
@testable import Life_USTC

@MainActor
final class ServerRenderedContentTests: XCTestCase {
    func testRendersBlocksAndMathWithoutDuplicatingKaTeXFallback() async throws {
        let html = """
        <p>Before the table.</p><table><tr><th>Room</th></tr><tr><td>East 101</td></tr></table>
        <span class="katex"><span class="katex-mathml"><math xmlns="http://www.w3.org/1998/Math/MathML"><mfrac><mn>1</mn><mn>2</mn></mfrac></math></span><span class="katex-html" aria-hidden="true">duplicate formula</span></span>
        <p>After the formula.</p>
        """
        let host = UIHostingController(rootView: ServerRenderedContent(html: html))
        let window = mount(host)
        defer { window.isHidden = true; window.rootViewController = nil }
        let webView = try await waitForWebView(in: host.view)
        try await waitForBody(webView, containing: "After the formula.")
        let result = try await webView.evaluateJavaScript("""
        ({text: document.body.innerText, rows: document.querySelectorAll('tr').length,
          mathHeight: document.querySelector('math').getBoundingClientRect().height,
          fallback: getComputedStyle(document.querySelector('.katex-html')).display})
        """) as? [String: Any]
        XCTAssertEqual(result?["rows"] as? Int, 2)
        XCTAssertEqual(result?["fallback"] as? String, "none")
        XCTAssertFalse((result?["text"] as? String ?? "").contains("duplicate formula"))
        XCTAssertGreaterThan(result?["mathHeight"] as? Double ?? 0, 0)
        XCTAssertFalse(webView.scrollView.isScrollEnabled)
        withExtendedLifetime(host) {}
    }

    func testUpdatedCanonicalBodyReplacesPreviousContent() async throws {
        let host = UIHostingController(rootView: ServerRenderedContent(html: "<p>Original body.</p>"))
        let window = mount(host)
        defer { window.isHidden = true; window.rootViewController = nil }
        let webView = try await waitForWebView(in: host.view)
        try await waitForBody(webView, containing: "Original body.")
        host.rootView = ServerRenderedContent(html: "<h2>Edited body.</h2><p>New paragraph.</p>")
        host.view.layoutIfNeeded()
        try await waitForBody(webView, containing: "New paragraph.")
        let text = try await webView.evaluateJavaScript("document.body.innerText") as? String
        XCTAssertTrue(text?.contains("Edited body.") == true)
        XCTAssertFalse(text?.contains("Original body.") == true)
        withExtendedLifetime(host) {}
    }

    private func mount(_ host: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return window
    }

    private func waitForWebView(in view: UIView) async throws -> WKWebView {
        for _ in 0..<100 {
            view.layoutIfNeeded()
            if let webView = findWebView(in: view) { return webView }
            try await Task.sleep(for: .milliseconds(50))
        }
        return try XCTUnwrap(findWebView(in: view), "SwiftUI did not mount the canonical HTML reader")
    }

    private func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        return view.subviews.lazy.compactMap { self.findWebView(in: $0) }.first
    }

    private func waitForBody(_ webView: WKWebView, containing value: String) async throws {
        for _ in 0..<100 {
            if let text = try? await webView.evaluateJavaScript("document.body?.innerText"),
               (text as? String)?.contains(value) == true { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Canonical HTML did not finish loading: \(value)")
    }
}
