import SafariServices
import SwiftUI

enum ServerAccountWebPage: String, CaseIterable, Identifiable {
    case profile, preferences, accounts, security, authorizations, danger, administration

    var id: String { rawValue }
    var path: String {
        self == .administration ? "/admin" : "/account/settings/\(rawValue)"
    }
    var title: LocalizedStringKey {
        switch self {
        case .profile: "Profile and Avatar"
        case .preferences: "Website Preferences"
        case .accounts: "Linked Accounts and Passkeys"
        case .security: "Sessions and Security Activity"
        case .authorizations: "Authorized Apps"
        case .danger: "Delete Account"
        case .administration: "Administration"
        }
    }
    var symbol: String {
        switch self {
        case .profile: "person.crop.circle"
        case .preferences: "slider.horizontal.3"
        case .accounts: "key"
        case .security: "clock.badge.checkmark"
        case .authorizations: "app.badge.checkmark"
        case .danger: "person.crop.circle.badge.minus"
        case .administration: "person.badge.shield.checkmark"
        }
    }

    func url(baseURL: URL) -> URL { baseURL.appendingPathComponent(path) }
}

struct ServerAccountManagementView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var selectedPage: ServerAccountWebPage?

    var body: some View {
        List {
            Section {
                ForEach([ServerAccountWebPage.profile, .preferences, .accounts, .security, .authorizations]) { page in
                    pageButton(page)
                }
            } footer: {
                Text("These settings open the Life@USTC website. Sign in there if asked, and check which account you are managing.")
            }
            Section {
                NavigationLink {
                    ServerAccountActivityView()
                } label: {
                    Label("This App's Activity", systemImage: "list.bullet.rectangle")
                }
                .accessibilityIdentifier("account_app_activity")
            }
            Section {
                pageButton(.administration)
            } footer: {
                Text("The website verifies administrator access for moderation and management.")
            }
            Section {
                pageButton(.danger)
            } footer: {
                Text("Account deletion requires confirmation on the website.")
            }
            if let error = account.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Refresh Account") { Task { await account.loadUser() } }
                }
            }
        }
        .navigationTitle("Account Management")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPage, onDismiss: {
            Task {
                await account.loadUser()
                NotificationCenter.default.post(name: .serverWorkspaceDidChange, object: nil)
            }
        }) { page in
            ServerAccountBrowser(url: page.url(baseURL: ServerClient.shared.baseURL))
                .ignoresSafeArea()
        }
    }

    private func pageButton(_ page: ServerAccountWebPage) -> some View {
        Button { selectedPage = page } label: {
            HStack {
                Label(page.title, systemImage: page.symbol)
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("account_web_\(page.rawValue)")
    }
}

private struct ServerAccountBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
