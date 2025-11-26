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

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground

        let webView = WKWebView(frame: .zero)
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

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

@available(iOS 26, *)
struct NewBroserView: View {
    @Environment(\.pixelLength) var onePixel

    @Binding var url: URL
    @Binding var useReeed: Bool
    @Binding var reeedMode: ReeedEnabledMode

    @State var page = WebPage()

    var body: some View {
        WebView(page)
            .onAppear {
                page.load(url)
                page.isInspectable = true
            }
            .padding(.top, onePixel)
            .ignoresSafeArea(.container, edges: .bottom)
    }
}

struct Browser: View {
    @Environment(\.dismiss) var dismiss
    @State var useReeed = false
    @State var prepared = false
    @State var reeedMode: ReeedEnabledMode = .userDefined
    @State var url: URL

    var title: LocalizedStringKey = "Detail"

    var contentView: some View {
        Group {
            if useReeed {
                ReeeederView(url: url, options: .init(includeExitReaderButton: false))
            } else {
                if #available(iOS 26, *) {
                    NewBroserView(url: $url, useReeed: $useReeed, reeedMode: $reeedMode)
                } else {
                    BrowserUIKitView(url: $url, useReeed: $useReeed, reeedMode: $reeedMode)
                        .ignoresSafeArea(.container, edges: .bottom)
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
                }
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
                Button {
                    useReeed.toggle()
                } label: {
                    Label(
                        useReeed ? "Exit Reeeder" : "Reeeder",
                        systemImage: useReeed ? "doc.plaintext.fill" : "doc.plaintext"
                    )
                }
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .task {
                if !prepared {
                    do {
                        reeedMode = sharedSchoolExport.reeedEnabledMode(url)

                        if reeedMode == .always {
                            useReeed = true
                        }

                        try await sharedSchoolExport.setCookiesBeforeWebView?(url)
                    } catch {
                        debugPrint(error)
                    }
                    prepared = true
                }
            }
    }
}
