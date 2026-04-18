//
//  ServerAccountView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct ServerAccountView: View {
    @Bindable private var store = ServerAccountStore.shared

    var body: some View {
        List {
            if let user = store.user {
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
                        store.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else if store.isAuthenticated {
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
                            Task { await store.login() }
                        } label: {
                            if store.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isLoading)
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                LabeledContent("Server", value: ServerClient.shared.baseURL.host() ?? "")
                LabeledContent("Status", value: store.isAuthenticated ? "Connected" : "Not connected")
            } header: {
                Text("Server Info")
            }

            if let error = store.error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Server Account")
        .task { await store.loadUser() }
    }
}

#Preview {
    NavigationStack {
        ServerAccountView()
    }
}
