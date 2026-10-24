import SwiftUI

struct ServerSupportView: View {
    var body: some View {
        List {
            Section("Usage Guides") {
                guide("Mobile App", path: "usage/mobile", symbol: "iphone")
                guide("Bot", path: "usage/bot", symbol: "bubble.left.and.bubble.right")
                guide("MCP", path: "usage/mcp", symbol: "app.connected.to.app.below.fill")
                guide("Command Line", path: "usage/cli", symbol: "terminal")
            }
            Section("Community Guides") {
                guide("Markdown Support", path: "guides/markdown-support", symbol: "textformat")
                guide("Comment Guide", path: "community/comments/guide", symbol: "text.bubble")
            }
        }
        .navigationTitle("Help and Guides")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guide(_ title: LocalizedStringKey, path: String, symbol: String) -> some View {
        Link(destination: ServerClient.shared.baseURL.appendingPathComponent(path)) {
            Label(title, systemImage: symbol)
        }
        .accessibilityIdentifier("guide_\(path)")
    }
}
