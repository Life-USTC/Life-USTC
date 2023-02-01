//
//  LegalPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

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
