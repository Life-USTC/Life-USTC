//
//  AboutPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

extension Bundle {
    var releaseNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
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
                    .onTapGesture(count: 5) {
                        UIPasteboard.general.string = String(describing: Array(userDefaults.dictionaryRepresentation()))
                    }
#if os(iOS)
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 15))
#endif
                    .contextMenu {
                        ShareLink(item: "Life@USTC") {
                            Label("Share this app", systemImage: "square.and.arrow.up")
                        }
//                        Button {
//                            openURL(URL(string: "https://www.pixiv.net/artworks/97582506")!)
//                        } label: {
//                            Label("Visit Icon original post", systemImage: "network")
//                        }
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
