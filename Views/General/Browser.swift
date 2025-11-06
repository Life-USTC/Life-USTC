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
    var reeedMode: ReeedEnabledMode

    @Binding var useReeed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: BrowserUIKitView
        weak var viewController: UIViewController?
        var webView: WKWebView?
        var toolbar: UIToolbar?
        var backItem: UIBarButtonItem?
        var forwardItem: UIBarButtonItem?
        var readerItem: UIBarButtonItem?
        var canGoBackObs: NSKeyValueObservation?
        var canGoForwardObs: NSKeyValueObservation?

        init(_ parent: BrowserUIKitView) {
            self.parent = parent
        }

        func setupObservers(for webView: WKWebView) {
            canGoBackObs = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                self?.backItem?.isEnabled = webView.canGoBack
            }
            canGoForwardObs = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                self?.forwardItem?.isEnabled = webView.canGoForward
            }
        }

        @objc func goBack() {
            webView?.goBack()
        }

        @objc func goForward() {
            webView?.goForward()
        }

        @objc func reload() {
            webView?.reload()
        }

        @objc func share() {
            guard let vc = viewController, let url = webView?.url else { return }
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            vc.present(activity, animated: true)
        }

        @objc func toggleReader() {
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
        webView.allowsBackForwardNavigationGestures = true

        let toolbar = UIToolbar()
        let toolbarItems = createToolbarItems(for: context.coordinator)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        context.coordinator.viewController = vc
        context.coordinator.webView = webView
        context.coordinator.toolbar = toolbar

        toolbar.items =
            reeedMode == .never
            ? [
                toolbarItems.back,
                toolbarItems.forward,
                toolbarItems.flexible,
                toolbarItems.reload,
                toolbarItems.flexible,
                toolbarItems.share,
            ]
            : [
                toolbarItems.back,
                toolbarItems.forward,
                toolbarItems.flexible,
                toolbarItems.reload,
                toolbarItems.flexible,
                toolbarItems.reader,
                toolbarItems.share,
            ]
        vc.view.addSubview(webView)
        vc.view.addSubview(toolbar)

        setupConstraints(webView: webView, toolbar: toolbar, viewController: vc, coordinator: context.coordinator)

        context.coordinator.setupObservers(for: webView)
        webView.load(URLRequest(url: url))

        return vc
    }

    func createToolbarItems(for coordinator: Coordinator) -> (
        back: UIBarButtonItem, forward: UIBarButtonItem, reload: UIBarButtonItem, share: UIBarButtonItem,
        flexible: UIBarButtonItem, reader: UIBarButtonItem
    ) {
        let back = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.goBack)
        )

        let forward = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.goForward)
        )

        let reload = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: coordinator,
            action: #selector(Coordinator.reload)
        )

        let share = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: coordinator,
            action: #selector(Coordinator.share)
        )

        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let reader = UIBarButtonItem(
            title: "Reeed",
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.toggleReader)
        )
        reader.image = UIImage(systemName: useReeed ? "doc.plaintext.fill" : "doc.plaintext")

        coordinator.backItem = back
        coordinator.forwardItem = forward
        coordinator.readerItem = reader

        return (back, forward, reload, share, flexible, reader)
    }

    func setupConstraints(
        webView: WKWebView,
        toolbar: UIToolbar,
        viewController vc: UIViewController,
        coordinator: Coordinator
    ) {
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8),

            toolbar.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor),
        ])

        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if context.coordinator.webView?.url != url {
            context.coordinator.webView?.load(URLRequest(url: url))
        }
        context.coordinator.refreshReaderAppearance()
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.canGoBackObs?.invalidate()
        coordinator.canGoForwardObs?.invalidate()
        coordinator.webView?.navigationDelegate = nil
    }
}

struct Browser: View {
    @Environment(\.dismiss) var dismiss
    @State var useReeed = false
    @State var prepared = false
    @State var reeedMode: ReeedEnabledMode = .userDefined

    var url: URL
    var title: LocalizedStringKey = "Detail"

    var contentView: some View {
        Group {
            if prepared {
                if useReeed {
                    ReeeederView(url: url, options: .init(includeExitReaderButton: false))
                        .toolbar {
                            ToolbarItemGroup(placement: .bottomBar) {
                                Spacer()
                                Button {
                                    useReeed.toggle()
                                } label: {
                                    Label("Exit Reader", systemImage: "doc.plaintext")
                                }
                                ShareLink(item: url) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                } else {
                    BrowserUIKitView(url: url, reeedMode: reeedMode, useReeed: $useReeed)
                }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    var body: some View {
        contentView
            .ignoresSafeArea()
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .id(url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Set cookies before allowing web view to load
                if !prepared {
                    do {
                        // Determine reed mode for this URL
                        reeedMode = SchoolExport.shared.reeedEnabledMode(for: url)

                        // Auto-enable Reed if mode is .always
                        if reeedMode == .always {
                            useReeed = true
                        }

                        try await SchoolExport.shared.setCookiesBeforeWebView?(url)
                    } catch {
                        debugPrint(error)
                    }
                    prepared = true
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)  // avoid size change
    }
}
