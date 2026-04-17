//
//  ServerAccountView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import AuthenticationServices
import SwiftUI

struct ServerAccountView: View {
    @State private var user: ServerUser?
    @State private var isLoading = false
    @State private var isLoggingIn = false
    @State private var error: String?

    private var isAuthenticated: Bool {
        ServerClient.shared.isAuthenticated
    }

    var body: some View {
        List {
            if let user {
                Section {
                    HStack(spacing: 12) {
                        if let imageURL = user.image,
                            let url = URL(string: imageURL)
                        {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                Circle().fill(.quaternary)
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name ?? user.username ?? "User")
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else if isAuthenticated {
                Section {
                    HStack {
                        Text("Loading account…")
                        Spacer()
                        ProgressView()
                    }
                }
            } else {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("Sign in to life-ustc.tiankaima.dev to enable cloud features like Todos, Comments, and data sync.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            Task { await login() }
                        } label: {
                            if isLoggingIn {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoggingIn)
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                LabeledContent("Server", value: ServerClient.baseURL.host() ?? "")
                LabeledContent("Status", value: isAuthenticated ? "Connected" : "Not connected")
            } header: {
                Text("Server Info")
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Server Account")
        .task { await loadUser() }
    }

    private func loadUser() async {
        guard isAuthenticated else { return }
        isLoading = true
        do {
            user = try await ServerClient.shared.fetchCurrentUser()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func login() async {
        isLoggingIn = true
        error = nil
        do {
            try await ServerAuth.shared.login()
            await loadUser()
        } catch {
            if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                self.error = error.localizedDescription
            }
        }
        isLoggingIn = false
    }

    private func logout() {
        ServerAuth.shared.logout()
        user = nil
        error = nil
    }
}

#Preview {
    NavigationStack {
        ServerAccountView()
    }
}
