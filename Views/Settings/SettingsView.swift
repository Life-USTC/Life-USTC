//
//  SettingsView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct SettingsView: View {
    @Bindable private var account = ServerAccountStore.shared
    @AppStorage("productionDebugEnabled") private var debugEnabled = false

    private var visibleSchoolSettings: [SettingWithView] {
        SchoolSystem.current.settings.filter { !$0.debugOnly || debugEnabled }
    }

    var body: some View {
        List {
            // MARK: - Account (top section)
            Section {
                if let user = account.user {
                    NavigationLink(destination: ServerAccountView()) {
                        HStack(spacing: 12) {
                            if let imageURL = user.image, let url = URL(string: imageURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                } placeholder: {
                                    Circle().fill(.quaternary)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name ?? user.username ?? "User")
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("settings_server_account")
                } else if account.isAuthenticated {
                    NavigationLink(destination: ServerAccountView()) {
                        HStack {
                            ProgressView()
                            Text("Loading account…")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    .accessibilityIdentifier("settings_server_account")
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not signed in")
                                .font(.headline)
                            Text("Sign in for Todos, Comments & sync")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await account.login() }
                        } label: {
                            if account.isLoading {
                                ProgressView()
                            } else {
                                Text("Sign In")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(account.isLoading)
                    }
                    .accessibilityIdentifier("settings_server_account")
                }
            }

            // MARK: - General
            Section {
                NavigationLink("Home Page Settings", destination: HomeSettingPage())
                    .accessibilityIdentifier("settings_home_settings")
                NavigationLink("Feed Source Settings", destination: FeedSetingsPage())
                    .accessibilityIdentifier("settings_feed_settings")
                NavigationLink("Exam Settings", destination: ExamSettingsPage())
                    .accessibilityIdentifier("settings_exam_settings")
            } header: {
                Text("General")
                    .textCase(.none)
            }

            // MARK: - School (filters debugOnly items)
            if !visibleSchoolSettings.isEmpty {
                Section {
                    ForEach(visibleSchoolSettings) { setting in
                        NavigationLink(setting.name) {
                            AnyView(setting.destinationView())
                        }
                    }
                } header: {
                    Text("School")
                        .textCase(.none)
                }
            }

            // MARK: - More
            Section {
                NavigationLink("About Life@USTC", destination: AboutPage())
                    .accessibilityIdentifier("settings_about")
                NavigationLink("Legal Info", destination: LegalPage())
                    .accessibilityIdentifier("settings_legal")
                if debugEnabled {
                    NavigationLink("Debug Logs", destination: DebugLogView())
                        .accessibilityIdentifier("settings_debug_logs")
                }
            } header: {
                Text("More")
                    .textCase(.none)
            }
        }
        .navigationTitle("Settings")
        .task { await account.loadUser() }
    }
}
