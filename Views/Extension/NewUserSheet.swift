//
//  NewUser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

extension ContentView {
    func newUserSheet() -> some View {
        NavigationStack {
            // Here a navigationLink is perferred over seprate window for annimation and more control.
            VStack {
                TitleAndSubTitle(title: "Choose an identity",
                                 subTitle: "You could modify this later in app settings",
                                 style: .caption)
                List {
                    ForEach(userTypeDescription.sorted(by: {$0.key.hashValue < $1.key.hashValue}), id:\.key.hashValue) { userType, description in
                        Button {
                            withAnimation {
                                firstLogin = false
                                self.userType = userType
                            }
                        } label: {
                            HStack {
                                TitleAndSubTitle(title: String(describing: userType).capitalized,
                                                 subTitle: description,
                                                 style: .substring)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                .listStyle(.plain)
                Spacer()
                
                Button {
                    firstLogin = false
                } label: {
                    Text("Skip for now")
                }
                .buttonStyle(BigButtonStyle())
            }
            .padding()
            .navigationTitle("Before we continue...")
        }
    }
}
