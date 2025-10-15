//
//  AboutPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI
import SwiftyJSON

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
        Image(life_ustc ? "OldIcon" : "Icon")
            .resizable()
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
    }

    var authorListView: some View {
        VStack {
            Text("Authors")
                .font(.system(.title2, design: .monospaced, weight: .semibold))

            VStack(alignment: .leading) {
                ForEach(contributorList, id: \.name) { contributor in
                    HStack {
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
    }

    var body: some View {
        VStack {
            Spacer()

            iconView
                .onTapGesture(count: 5) {
                    life_ustc.toggle()
                    changeAppIcon(to: life_ustc ? "OldAppIcon" : "NewAppIcon")
                }

            Text(life_ustc ? "Life@USTC" : "Study@USTC")
                .font(.system(.title, weight: .bold))
            Text(Bundle.main.versionDescription)
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
                .frame(height: 50)

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

struct AboutPage_Previews: PreviewProvider {
    static var previews: some View {
        AboutApp()
    }
}
