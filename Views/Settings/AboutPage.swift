//
//  AboutPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI
import SwiftyJSON

// The following GitHub does nothing than access GitHub's API to fetch contributor list.
private let githubDumbTokenA = "github_pat_11AV4QBHQ0I8IdqcDkTkvH_"
private let githubDumbTokenB =
    "gQyW7CGYb4OmlfJVApx3g7QsTo17d07SACsOAkpXkhBLN4NHZFZhg5zjWoy"

private let links: [(label: String, url: String)] = [
    ("GitHub:", "https://github.com/tiankaima/Life-USTC"),
    ("Discord:", "https://discord.gg/BxdsySpkYP"),
]

let shareURL = URL(
    string: "https://apps.apple.com/cn/app/life-ustc/id1660437438"
)!

struct AboutApp: View {
    @State var contributorList: [(name: String, avatar: URL?)] = [
        (
            "tiankaima",
            URL(string: "https://avatars.githubusercontent.com/u/91816094?v=4")
        ),
        (
            "odeinjul",
            URL(string: "https://avatars.githubusercontent.com/u/42104346?v=4")
        ),
    ]

    var iconView: some View {
        Image("Icon")
            .resizable()
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .contextMenu {
                ShareLink(item: shareURL) {
                    Label(
                        "Share this app",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
    }

    var authorListView: some View {
        HStack {
            Text("Author:")
                .font(.system(.title2, design: .monospaced, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(contributorList, id: \.name) { contributor in
                        AsyncImage(url: contributor.avatar) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 30, maxHeight: 30)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                        }
                        Text(contributor.name).fontWeight(.medium)
                            .font(.title3)
                    }
                }
            }
        }
    }

    var linksView: some View {
        VStack(alignment: .leading) {
            ForEach(links, id: \.label) { link in
                HStack {
                    Text(link.label)
                        .font(
                            .system(
                                .title2,
                                design: .monospaced,
                                weight: .semibold
                            )
                        )
                    Text(link.url).foregroundColor(.gray)

                    Spacer()
                }
            }
            .frame(height: 40)
        }
    }

    var body: some View {
        VStack {
            iconView
            Text("Life@USTC")
                .font(.system(.title, weight: .bold))
            Text(Bundle.main.versionDescription)
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary)

            Spacer()

            authorListView
            linksView
        }
        .padding()
        .task {
            onLoadFunc()
        }
        .navigationTitle("About Life@USTC")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension AboutApp {
    func onLoadFunc() {
        Task {
            var request = URLRequest(
                url: URL(
                    string:
                        "https://api.github.com/repos/tiankaima/Life-USTC/contributors"
                )!
            )
            request.httpMethod = "GET"
            request.setValue(
                "application/vnd.github+json",
                forHTTPHeaderField: "Accept"
            )
            request.setValue(
                "Bearer \(githubDumbTokenA + githubDumbTokenB)",
                forHTTPHeaderField: "Authorization"
            )
            request.setValue(
                "2022-11-28",
                forHTTPHeaderField: "X-GitHub-Api-Version"
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            if (response as! HTTPURLResponse).statusCode == 401 {
                // Token is expired for some reason
                return
            }

            let dataJson = try JSON(data: data)
            contributorList = dataJson.arrayValue.map {
                (
                    $0["login"].stringValue,
                    URL(string: $0["avatar_url"].stringValue)
                )
            }
        }
    }
}

extension Bundle {
    var releaseNumber: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }

    var versionDescription: String {
        "Ver: \(releaseNumber ?? "") build\(buildNumber ?? "")"
    }
}

struct AboutPage_Previews: PreviewProvider {
    static var previews: some View { AboutApp() }
}
