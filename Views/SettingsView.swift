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

struct AboutLifeAtUSTCView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                    .resizable()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.secondary, lineWidth: 2))
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 15))
                    .contextMenu {
                        ShareLink(item: "Life@USTC") {
                            Label("Share this app", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            let url = URL(string: "https://www.pixiv.net/artworks/97582506")!
                            UIApplication.shared.open(url)
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
                        .padding([.top,.bottom],2)
                    Text("https://github.com/tiankaima/Life-USTC")
                    
                    Text("Twitter")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top,.bottom],2)
                    Text("https://twitter.com/tiankaima")
                    
                    Text("Discord")
                        .fontWeight(.semibold)
                        .font(.title2)
                        .padding([.top,.bottom],2)
                    Text("https://discord.gg/BxdsySpkYP")
                }
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EmptyView: View {
    var body: some View {
        VStack {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 60))
                .frame(width: 100, height: 100)
                .foregroundColor(.yellow)
                .symbolRenderingMode(.hierarchical)
            Text("Comming Soon~")
                .font(.title2)
                .bold()
        }
//        .border(.red)
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
                        Text("USTC CAS DISCLAIMER:")
                        Text("casFullHint")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
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
                    NavigationLink("CAS Settings", destination: CASLoginView(casLoginSheet: .constant(false)))
                    NavigationLink("Change User Type", destination: UserTypeView())
                    NavigationLink("Notification Settings", destination: EmptyView())
                }
                
                Section {
                    NavigationLink("About Life@USTC", destination: AboutLifeAtUSTCView())
                    NavigationLink("Legal Info", destination: LegalInfoView())
                }
            }
            .navigationTitle("Settings")
//            .searchable(text: $searchText, placement: .toolbar)
        }
    }
}
