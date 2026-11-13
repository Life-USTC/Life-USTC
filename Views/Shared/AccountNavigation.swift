import SwiftUI

enum AccountDestination: String, Identifiable {
    case account, settings, uploads
    var id: String { rawValue }

    @MainActor
    @ViewBuilder
    var view: some View {
        switch self {
        case .account: ServerAccountView()
        case .settings: SettingsView()
        case .uploads: ServerOwnedFilesView()
        }
    }
}

struct AccountMenu: View {
    @Bindable private var account = ServerAccountStore.shared
    let open: (AccountDestination) -> Void

    var body: some View {
        Menu {
            Button { open(.account) } label: {
                Label("Account", systemImage: "person.crop.circle")
            }
            .accessibilityIdentifier("account_menu_account")
            Button { open(.settings) } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("account_menu_settings")
            if account.isAuthenticated {
                Button { open(.uploads) } label: {
                    Label("My Uploads", systemImage: "folder")
                }
                .accessibilityIdentifier("account_menu_uploads")
            }
        } label: {
            Group {
                if let image = account.user?.image, let url = URL(string: image) {
                    AsyncImage(url: url) { image in image.resizable() } placeholder: {
                        Image(systemName: "person.crop.circle")
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Account menu")
        .accessibilityIdentifier("account_menu")
    }
}
