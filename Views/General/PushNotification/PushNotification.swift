//
//  PushNotification.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-04-24.
//

import SwiftOverlayShims
import SwiftUI

@ViewBuilder func HTextField(title: any StringProtocol, text: Binding<String>) -> AnyView {
    AnyView(
        LabeledContent {
            TextField(title, text: text, axis: .vertical)
        } label: {
            Text(title)
        }
    )
}

#if os(iOS)
struct PushNotification: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State var title: String = ""
    @State var subTitle: String = ""
    @State var content: String = ""
    @State var tags: [String] = []

    var body: some View {
        Form {
            Section {
                HTextField(title: "Title", text: $title)
                HTextField(title: "Subtitle", text: $subTitle)
                HTextField(title: "Content", text: $content)
            } header: {
                Text("Details")
                    .textCase(.none)
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(0 ..< 10) { index in
                            Toggle("Tag \(index)", isOn:
                                .init(get: {
                                    tags.contains("Tag \(index)")
                                }, set: { newValue in
                                    if newValue {
                                        tags.append("Tag \(index)")
                                    } else {
                                        tags.removeAll(where: { $0 == "Tag \(index)" })
                                    }
                                }))
                                .toggleStyle(.button)
                        }
                    }
                }
            } header: {
                Text("Tags")
                    .textCase(.none)
            }

            Button(role: .destructive) {} label: {
                Text("Push")
            }
        }
        .onTapGesture {
            // dismiss keyboard
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Push Notification")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PushNotification_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PushNotification()
                .environmentObject(AppDelegate())
        }
    }
}
#endif
