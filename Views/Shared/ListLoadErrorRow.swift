import SwiftUI

struct ListLoadErrorRow: View {
    let message: String
    var isLoading = false
    var retryIdentifier = "list.retry"
    let retry: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.caption).foregroundStyle(.red)
            Button("Retry") { Task { await retry() } }
                .disabled(isLoading)
                .accessibilityIdentifier(retryIdentifier)
        }
    }
}
