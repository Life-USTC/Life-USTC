//
//  ServerBackendSettingsView.swift
//  Life@USTC
//
//  Debug-only view for switching the server backend URL.
//  Accessible from Settings when production debug mode is enabled.
//

import SwiftUI

struct ServerBackendSettingsView: View {
    @Bindable private var account = ServerAccountStore.shared

    @State private var selectedEnvironment: ServerEnvironment = .production
    @State private var customURL: String = ""
    @State private var showConfirmation = false
    @State private var pendingURL: URL?

    private var currentURL: String {
        ServerClient.shared.baseURL.absoluteString
    }

    var body: some View {
        Form {
            statusSection
            environmentSection
            actionsSection
        }
        .navigationTitle("Backend Server")
        .onAppear { loadCurrentSelection() }
        .alert("Switch Backend?", isPresented: $showConfirmation) {
            Button("Switch", role: .destructive) { applyChange() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will sign you out and connect to:\n\(pendingURL?.absoluteString ?? "")")
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                Text("Current Backend")
                Spacer()
                Text(currentURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if account.isAuthenticated {
                HStack {
                    Text("Auth Status")
                    Spacer()
                    Label("Authenticated", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Status").textCase(.none)
        }
    }

    private var environmentSection: some View {
        Section {
            environmentRow(.production)
            environmentRow(.localhost)
            customEnvironmentRow
        } header: {
            Text("Environment").textCase(.none)
        } footer: {
            Text("⚠️ Switching backends clears your login session. Localhost only works in Simulator; for physical devices, use your Mac's local IP address.")
                .font(.caption2)
        }
    }

    private func environmentRow(_ env: ServerEnvironment) -> some View {
        HStack {
            Image(systemName: selectedEnvironment == env ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selectedEnvironment == env ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading) {
                Text(env.displayName)
                Text(env.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture { selectedEnvironment = env }
    }

    private var customEnvironmentRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: selectedEnvironment == .custom ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selectedEnvironment == .custom ? Color.accentColor : Color.secondary)
                Text(ServerEnvironment.custom.displayName)
            }
            .onTapGesture { selectedEnvironment = .custom }

            if selectedEnvironment == .custom {
                TextField("https://192.168.1.x:3000", text: $customURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Apply") {
                guard let url = resolvedURL else { return }
                pendingURL = url
                showConfirmation = true
            }
            .disabled(resolvedURL == nil || resolvedURL?.absoluteString == currentURL)

            if currentURL != ServerEnvironment.production.rawValue {
                Button("Reset to Production", role: .destructive) {
                    ServerClient.shared.resetToProduction()
                    account.onBackendChanged()
                    selectedEnvironment = .production
                    customURL = ""
                }
            }
        }
    }

    // MARK: - Helpers

    private var resolvedURL: URL? {
        switch selectedEnvironment {
        case .production: return URL(string: ServerEnvironment.production.rawValue)
        case .localhost: return URL(string: ServerEnvironment.localhost.rawValue)
        case .custom:
            let trimmed = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : URL(string: trimmed)
        }
    }

    private func loadCurrentSelection() {
        let current = currentURL
        if current == ServerEnvironment.production.rawValue {
            selectedEnvironment = .production
        } else if current == ServerEnvironment.localhost.rawValue {
            selectedEnvironment = .localhost
        } else {
            selectedEnvironment = .custom
            customURL = current
        }
    }

    private func applyChange() {
        guard let url = pendingURL else { return }
        ServerClient.shared.reconfigure(baseURL: url)
        account.onBackendChanged()
    }
}
