//
//  AboutPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI
import SwiftyJSON

let shareURL = URL(string: "https://xzkd.ustc.edu.cn/")!

struct AboutApp: View {
    @AppStorage("Life-USTC") var life_ustc: Bool = false
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
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
            .contextMenu {
                ShareLink(item: shareURL) {
                    Label(
                        "Share this app",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
    }

    var oldIconView: some View {
        Image("OldIcon")
            .resizable()
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
    }

    var linkView: some View {
        VStack(alignment: .leading) {
            Text("More Info:")
                .font(.system(.title2, design: .monospaced, weight: .semibold))

            Text(shareURL.absoluteString)
                .font(.title3)
                .foregroundColor(.accentColor)
                .onTapGesture {
                    UIApplication.shared.open(shareURL)
                }
                .frame(height: 30)
                .padding(.leading, 30)
        }
        .hStackLeading()
    }

    var authorListView: some View {
        VStack(alignment: .leading) {
            Text("Author:")
                .font(.system(.title2, design: .monospaced, weight: .semibold))

            ForEach(contributorList, id: \.name) { contributor in
                HStack {
                    AsyncImage(url: contributor.avatar) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
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
        .hStackLeading()
    }

    var body: some View {
        VStack {
            if life_ustc {
                oldIconView
                    .onTapGesture(count: 5) {
                        life_ustc.toggle()
                        changeAppIcon(to: "NewAppIcon")
                    }
            } else {
                iconView
                    .onTapGesture(count: 5) {
                        life_ustc.toggle()
                        changeAppIcon(to: "OldAppIcon")
                    }
            }
            Text(life_ustc ? "Life@USTC" : "Study@USTC")
                .font(.system(.title, weight: .bold))
            Text(Bundle.main.versionDescription)
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary)

            Spacer()

            linkView
            authorListView

            Spacer()
        }
        .padding()
        .navigationTitle(life_ustc ? "About Life@USTC" : "About Study@USTC")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changeAppIcon(to iconName: String) {
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Error setting alternate icon \(error.localizedDescription)")
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
