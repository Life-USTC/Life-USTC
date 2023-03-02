//
//  AboutPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI
import SwiftyJSON

private let githubDumbToken = "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"

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
    let links: [(label: String, url: String)] = [("GitHub", "https://github.com/tiankaima/Life-USTC"),
//                                                 ("Twitter","https://twitter.com/tiankaima"),
                                                 ("Discord", "https://discord.gg/BxdsySpkYP")]
    @State var contributorList: [(name: String, avatar: URL?)] = []

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image("Icon")
                    .resizable()
                    .frame(width: 200, height: 200)
                    .onTapGesture(count: 5) {
#if os(macOS)
                        NSPasteboard.general.setString(String(describing: Array(userDefaults.dictionaryRepresentation())), forType: .string)
#else
                        UIPasteboard.general.string = String(describing: Array(userDefaults.dictionaryRepresentation()))
#endif
                    }
#if os(iOS)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
#endif
                    .contextMenu {
                        ShareLink(item: "Life@USTC") {
                            Label("Share this app", systemImage: "square.and.arrow.up")
                        }
                    }
                    .shadow(radius: 10)
                Spacer()
                Text("Life@USTC")
                    .font(.title)
                    .bold()

                Text("Ver: \(Bundle.main.releaseNumber ?? "") build\(Bundle.main.buildNumber ?? "")")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)

                Spacer()

                HStack {
                    Text("Author")
                        .fontWeight(.semibold)
                        .font(.title2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(contributorList, id: \.name) { contributor in
                                AsyncImage(url: contributor.avatar) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 30, maxHeight: 30)
                                        .clipShape(Circle())
                                } placeholder: {
                                    ProgressView()
                                }
                                Text(contributor.name)
                                    .fontWeight(.medium)
                                    .font(.title3)
                            }
                        }
                    }
                }

                VStack(alignment: .leading) {
                    ForEach(links, id: \.label) { link in
                        HStack {
                            Text(link.label)
                                .fontWeight(.semibold)
                                .font(.title2)
                                .padding([.top, .bottom], 2)
                            Text(link.url)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(height: 40)
                }
                .hStackLeading()
            }
            .padding()
            .navigationBarTitle("About", displayMode: .inline)
            .toolbar(.hidden, for: .tabBar)
        }
        .onAppear {
            Task {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/tiankaima/Life-USTC/contributors")!)
                request.httpMethod = "GET"
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(githubDumbToken)", forHTTPHeaderField: "Authorization")
                request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

                let (data, _) = try await URLSession.shared.data(for: request)
                let dataJson = try JSON(data: data)
                for (_, userInfo) in dataJson {
                    contributorList.append((userInfo["login"].stringValue, URL(string: userInfo["avatar_url"].stringValue)))
                }
            }
        }
    }
}

struct AboutPage_Previews: PreviewProvider {
    static var previews: some View {
        AboutLifeAtUSTCView()
    }
}
