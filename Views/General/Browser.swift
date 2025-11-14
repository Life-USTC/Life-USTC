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

        vc.view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])
        webView.scrollView.scrollIndicatorInsets = webView.scrollView.contentInset

        webView.load(URLRequest(url: url))

        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@available(iOS 26, *)
struct NewBroserView: View {
    @Binding var url: URL
    @Binding var useReeed: Bool
    @Binding var reeedMode: ReeedEnabledMode

    @State var page = WebPage()

    var body: some View {
        WebView(page)
            .onAppear {
                page.load(url)
            }
            .padding(.top, 0.1)
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
            .toolbar(.hidden, for: .tabBar)
            .id(url)
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
                        reeedMode = SchoolExport.shared.reeedEnabledMode(for: url)

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
    }
}
