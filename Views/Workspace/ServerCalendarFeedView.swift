import SwiftUI

struct ServerCalendarFeedView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var feedURL: URL?
    @State private var isLoading = false
    @State private var error: String?
    @State private var copied = false
    @State private var feedRevision: UUID?
    @State private var generation = 0

    var body: some View {
        List {
            if !account.isAuthenticated {
                YoungLoginRequiredView()
            } else {
                Section {
                    Text("Use your personal iCal link in a calendar app to keep subscribed events up to date.")
                    Text("This private link grants access to your calendar. Share it only with trusted apps.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let feedURL, feedRevision == ServerClient.shared.sessionRevision {
                    Section {
                        ShareLink(item: feedURL) {
                            Label("Share calendar link", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("calendar_feed_share")
                        Button {
                            guard ServerClient.shared.isAuthenticated,
                                  feedRevision == ServerClient.shared.sessionRevision else { return }
                            UIPasteboard.general.url = feedURL
                            copied = true
                        } label: {
                            Label(LocalizedStringKey(copied ? "Copied" : "Copy calendar link"),
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .accessibilityIdentifier("calendar_feed_copy")
                    }
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if error == nil {
                    Section {
                        Text("Calendar link unavailable")
                        Text("Add a section subscription or sign in again to enable calendar access.")
                            .foregroundStyle(.secondary)
                        NavigationLink("Section subscriptions") { ServerSubscriptionsView() }
                        NavigationLink("Server Account") { ServerAccountView() }
                    }
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await load() } }
                            .accessibilityIdentifier("calendar_feed_retry")
                    }
                }
            }
        }
        .navigationTitle("Calendar subscription")
        .task(id: account.sessionRevision) { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        generation += 1
        let requestGeneration = generation
        feedURL = nil
        feedRevision = nil
        copied = false
        error = nil
        let client = ServerClient.shared
        let revision = client.sessionRevision
        guard client.isAuthenticated else {
            isLoading = false
            return
        }
        isLoading = true
        defer { if requestGeneration == generation { isLoading = false } }
        do {
            let url = try await client.fetchPersonalCalendarFeedURL()
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            feedURL = url
            feedRevision = revision
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
