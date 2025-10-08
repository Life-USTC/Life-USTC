//
//  Browser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import Reeeed
import SwiftUI
import WebKit

struct SwiftUIWebView: UIViewRepresentable {
    let webView: WKWebView
    var url: URL

    init(url: URL) {
        self.url = url
        self.webView = WKWebView(frame: .zero)
    }

    func makeUIView(context _: Context) -> WKWebView {
        self.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        self.webView.load(URLRequest(url: self.url))
    }
}

struct Browser: View {
    var url: URL
    var title: String = "Detail"
    var webView: SwiftUIWebView

    @State var useReeed = false
    @State var prepared = false

    var body: some View {
        Group {
            if prepared {
                if useReeed {
                    ReeeederView(url: url)
                } else {
                    webView
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .padding([.leading, .trailing], 2)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    webView.webView.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(useReeed || !webView.webView.canGoBack)

                Button {
                    webView.webView.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(useReeed || !webView.webView.canGoForward)

                Spacer()

                Button {
                    webView.webView.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(useReeed)

                Spacer()

                Button {
                    useReeed.toggle()
                } label: {
                    Label("Reeed", systemImage: useReeed ? "doc.plaintext.fill" : "doc.plaintext")
                }

                ShareLink(item: self.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
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
        self.webView = SwiftUIWebView(url: _url)
    }
}
