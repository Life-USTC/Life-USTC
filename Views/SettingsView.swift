//
//  SettingsView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

extension Bundle {
    var releaseNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

struct NotificationSettingView: View {
    var body: some View {
        NavigationStack {
            List {
                Button {
                    tryRequestAuthorization()
#if os(iOS)
                    UIApplication.shared.registerForRemoteNotifications()
#endif
                } label: {
                    Label("Upload Token", systemImage: "square.and.arrow.up")
                }

                Button {
                    tryRequestAuthorization()
#if os(iOS)
                    let uuidString = UUID().uuidString
                    let content = UNMutableNotificationContent()
                    content.title = "TestTitle"
                    content.body = "What the fuck is this"

                    // set trigger to nil to instantly trigger a update
                    let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
#endif
                } label: {
                    Label("Test Message", systemImage: "plus.square.dashed")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitle("Notification Settings", displayMode: .inline)
        }
    }
}

struct AboutLifeAtUSTCView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack {
                Image("Icon")
                    .resizable()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.secondary, lineWidth: 2))
#if os(iOS)
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 15))
#endif
                    .contextMenu {
                        ShareLink(item: "Life@USTC") {
                            Label("Share this app", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            openURL(URL(string: "https://www.pixiv.net/artworks/97582506")!)
                        } label: {
                            Label("Visit Icon original post", systemImage: "network")
                        }
                    }

                Text("Life@USTC")
                    .font(.title)
                    .bold()

                Text("Brought to you by @tiankaima")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)

                Text("Ver: \(Bundle.main.releaseNumber ?? "") build\(Bundle.main.buildNumber ?? "")")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .leading) {
                    Text("Github")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top, .bottom], 2)
                    Text("https://github.com/tiankaima/Life-USTC")

                    Text("Twitter")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top, .bottom], 2)
                    Text("https://twitter.com/tiankaima")

                    Text("Discord")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top, .bottom], 2)
                    Text("https://discord.gg/BxdsySpkYP")
                }
            }
            .padding()
            .navigationBarTitle("About", displayMode: .inline)
        }
    }
}

struct LegalInfoView: View {
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    VStack(alignment: .leading) {
                        Text("Icon source")
                        Text("Visit https://www.pixiv.net/artworks/97582506 for origin post, much thanks to original author.🥰")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Feedkit source")
                        Text("Visit https://github.com/nmdias/FeedKit (MIT License) for origin repo, much thanks to original author.😘")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("SwiftyJSON source")
                        Text("Visit https://github.com/SwiftyJSON/SwiftyJSON (MIT License) for origin repo, much thanks to repo contributors.🥳")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("USTC CAS DISCLAIMER:")
                        Text("casFullHint")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitle("Legal", displayMode: .inline)
        }
    }
}

struct SettingsView: View {
    @State var searchText = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Feed Source Settings", destination: EmptyView())
                    NavigationLink("CAS Settings", destination: CASLoginView.newPage)
                    NavigationLink("Change User Type", destination: UserTypeView())
                    NavigationLink("Notification Settings", destination: NotificationSettingView())
                }

                Section {
                    NavigationLink("About Life@USTC", destination: AboutLifeAtUSTCView())
                    NavigationLink("Legal Info", destination: LegalInfoView())
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
//            .searchable(text: $searchText, placement: .toolbar)
        }
    }
}
