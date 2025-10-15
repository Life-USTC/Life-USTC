//
//  LegalPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

let credit =
    "Credit to FeedKit, Fuzi, Introspect, Reeeed, SwiftFormat, SwiftSoup, SwiftyJSON, which all makes this app possible.😘"

struct LegalInfoView: View {
    var body: some View {
        VStack {
            List {
                VStack(alignment: .leading) {
                    Text("Open source code usage:")
                        .padding(.bottom, 2)
                    Text(credit)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationBarTitle("Legal", displayMode: .inline)
    }
}

struct LegalPage_Previews: PreviewProvider {
    static var previews: some View {
        LegalInfoView()
    }
}
