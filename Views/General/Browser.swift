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
    var reeedMode: ReeedEnabledMode

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: BrowserUIKitView
        weak var viewController: UIViewController?
        var webView: WKWebView?
        var toolbar: UIToolbar?
        var backItem: UIBarButtonItem?
        var forwardItem: UIBarButtonItem?
        var readerItem: UIBarButtonItem?
        var canGoBackObs: NSKeyValueObservation?
        var canGoForwardObs: NSKeyValueObservation?

        // Toolbar auto-hide properties
        var lastContentOffset: CGFloat = 0
        var isToolbarHidden = false
        var toolbarBottomConstraint: NSLayoutConstraint?

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

            // Set up scroll view delegate for toolbar hiding
            webView.scrollView.delegate = self
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
            guard let vc = viewController else { return }
            let activity = UIActivityViewController(activityItems: [parent.url], applicationActivities: nil)
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

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let toolbar = toolbar, let constraint = toolbarBottomConstraint else { return }

            if scrollView.contentOffset.y < 0
                || scrollView.contentOffset.y > (scrollView.contentSize.height - scrollView.frame.size.height)
            {
                return
            }
            let currentOffset = scrollView.contentOffset.y
            let diff = currentOffset - lastContentOffset
            lastContentOffset = currentOffset

            if diff < -4 && isToolbarHidden {
                showToolbar(toolbar: toolbar, constraint: constraint)
            } else if diff > 8 && !isToolbarHidden && currentOffset > 20 {
                hideToolbar(toolbar: toolbar, constraint: constraint)
            }
        }

        func hideToolbar(toolbar: UIToolbar, constraint: NSLayoutConstraint) {
            guard !isToolbarHidden else { return }

            let safeAreaInsets = self.viewController?.view.safeAreaInsets.bottom ?? 0
            let toolbarHeight = toolbar.frame.height + safeAreaInsets
            UIView.animate(
                withDuration: 0.3,
                animations: {
                    constraint.constant = toolbarHeight
                    toolbar.alpha = 0.0
                    self.viewController?.view.layoutIfNeeded()
                }
            ) { _ in
                self.isToolbarHidden = true
            }
        }

        func showToolbar(toolbar: UIToolbar, constraint: NSLayoutConstraint) {
            guard isToolbarHidden else { return }

            UIView.animate(
                withDuration: 0.3,
                animations: {
                    constraint.constant = 0
                    toolbar.alpha = 1.0
                    self.viewController?.view.layoutIfNeeded()
                }
            ) { _ in
                self.isToolbarHidden = false
            }
        }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground

        // Setup web view
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false

        // Setup toolbar
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        // Create toolbar items
        let toolbarItems = createToolbarItems(for: context.coordinator)

        // Store references
        context.coordinator.viewController = vc
        context.coordinator.webView = webView
        context.coordinator.toolbar = toolbar

        // Assign toolbar items based on mode
        toolbar.items =
            reeedMode == .never
            ? [
                toolbarItems.back, toolbarItems.forward, toolbarItems.flexible, toolbarItems.reload,
                toolbarItems.flexible, toolbarItems.share,
            ]
            : [
                toolbarItems.back, toolbarItems.forward, toolbarItems.flexible, toolbarItems.reload,
                toolbarItems.flexible, toolbarItems.reader, toolbarItems.share,
            ]

        // Add subviews
        vc.view.addSubview(webView)
        vc.view.addSubview(toolbar)

        // Setup constraints
        setupConstraints(webView: webView, toolbar: toolbar, viewController: vc, coordinator: context.coordinator)

        // Setup observers and load URL
        context.coordinator.setupObservers(for: webView)
        webView.load(URLRequest(url: url))

        return vc
    }

    private func createToolbarItems(for coordinator: Coordinator) -> (
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

    private func setupConstraints(
        webView: WKWebView,
        toolbar: UIToolbar,
        viewController vc: UIViewController,
        coordinator: Coordinator
    ) {
        let toolbarBottomConstraint = toolbar.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor)
        coordinator.toolbarBottomConstraint = toolbarBottomConstraint

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),

            toolbar.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            toolbarBottomConstraint,
        ])
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if context.coordinator.webView?.url != url {
            context.coordinator.webView?.load(URLRequest(url: url))
            if let toolbar = context.coordinator.toolbar, let constraint = context.coordinator.toolbarBottomConstraint,
                context.coordinator.isToolbarHidden
            {
                context.coordinator.showToolbar(toolbar: toolbar, constraint: constraint)
                context.coordinator.lastContentOffset = 0
            }
        }
        context.coordinator.refreshReaderAppearance()
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.canGoBackObs?.invalidate()
        coordinator.canGoForwardObs?.invalidate()
        coordinator.webView?.scrollView.delegate = nil
        coordinator.webView?.navigationDelegate = nil
    }
}

struct Browser: View {
    @State var useReeed = false
    @State var prepared = false
    @State private var reeedMode: ReeedEnabledMode = .userDefined

    var url: URL
    var title: LocalizedStringKey = "Detail"

    var contentView: some View {
        Group {
            if prepared {
                if useReeed {
                    ReeeederView(url: url, options: .init(includeExitReaderButton: false))
                } else {
                    BrowserUIKitView(url: url, useReeed: $useReeed, reeedMode: reeedMode)
                }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    var readerToolbar: some ToolbarContent {
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

    var body: some View {
        contentView
            .ignoresSafeArea()
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                if useReeed {
                    readerToolbar
                }
            }
            .id(url)
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

                        if let setCookiesBeforeWebView = SchoolExport.shared.setCookiesBeforeWebView {
                            try await setCookiesBeforeWebView(url)
                        }
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
