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
    let url: URL
    @Binding var useReeed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: BrowserUIKitView
        weak var viewController: UIViewController?
        var webView: WKWebView?
        var backItem: UIBarButtonItem?
        var forwardItem: UIBarButtonItem?
        var readerItem: UIBarButtonItem?
        var canGoBackObs: NSKeyValueObservation?
        var canGoForwardObs: NSKeyValueObservation?

        init(_ parent: BrowserUIKitView) { self.parent = parent }

        func setupObservers(for webView: WKWebView) {
            canGoBackObs = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                self?.backItem?.isEnabled = webView.canGoBack
            }
            canGoForwardObs = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                self?.forwardItem?.isEnabled = webView.canGoForward
            }
        }

        @objc func goBack() { webView?.goBack() }
        @objc func goForward() { webView?.goForward() }
        @objc func reload() { webView?.reload() }
        @objc func share() {
            guard let vc = viewController else { return }
            let activity = UIActivityViewController(activityItems: [parent.url], applicationActivities: nil)
            vc.present(activity, animated: true)
        }
        @objc func toggleReader() {
            // Switch to Reader (SwiftUI) mode
            parent.useReeed.toggle()
            refreshReaderAppearance()
        }

        func refreshReaderAppearance() {
            let symbol = parent.useReeed ? "doc.plaintext.fill" : "doc.plaintext"
            readerItem?.image = UIImage(systemName: symbol)
        }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground

        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let back = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.goBack)
        )
        let forward = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.goForward)
        )
        let reload = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: context.coordinator,
            action: #selector(Coordinator.reload)
        )
        let share = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: context.coordinator,
            action: #selector(Coordinator.share)
        )
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let reader = UIBarButtonItem(
            title: "Reeed",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.toggleReader)
        )
        // Add SF Symbol icon like SwiftUI Label
        reader.image = UIImage(systemName: useReeed ? "doc.plaintext.fill" : "doc.plaintext")

        context.coordinator.backItem = back
        context.coordinator.forwardItem = forward
        context.coordinator.readerItem = reader
        context.coordinator.viewController = vc
        context.coordinator.webView = webView

        toolbar.items = [back, forward, flexible, reload, flexible, reader, share]

        vc.view.addSubview(webView)
        vc.view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            toolbar.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor),
        ])

        context.coordinator.setupObservers(for: webView)

        webView.load(URLRequest(url: url))

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if context.coordinator.webView?.url != url {
            context.coordinator.webView?.load(URLRequest(url: url))
        }
        // Keep reader icon in sync with state changes from SwiftUI
        context.coordinator.refreshReaderAppearance()
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.canGoBackObs?.invalidate()
        coordinator.canGoForwardObs?.invalidate()
        coordinator.webView?.navigationDelegate = nil
    }
}

struct Browser: View {
    var url: URL
    var title: String = "Detail"

    @State var useReeed = false
    @State var prepared = false

    var body: some View {
        Group {
            if prepared {
                if useReeed {
                    ReeeederView(url: url)
                } else {
                    BrowserUIKitView(url: url, useReeed: $useReeed)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .toolbar(.hidden, for: .tabBar)
        // Provide a minimal bottom toolbar when in Reader mode (UIKit toolbar is used in web mode)
        .toolbar {
            if useReeed {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button {
                        useReeed.toggle()
                    } label: {
                        Label("Exit Reader", systemImage: "doc.plaintext")
                    }
                    ShareLink(item: self.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .id(url)
        .task {
            // Set cookies before allowing web view to load
            if !prepared {
                do {
                    if let setCookiesBeforeWebView = SchoolExport.shared.setCookiesBeforeWebView {
                        try await setCookiesBeforeWebView()
                    }
                } catch {
                    debugPrint(error)
                }
                prepared = true
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    init(url _url: URL, title: String = "Detail") {
        self.url = _url
        self.title = title
    }
}
