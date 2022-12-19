//
//  NewUser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct UserTypeView: View {
    @AppStorage("userType") var userType: UserType?
    @Binding var userTypeSheet: Bool
    var body: some View {
        NavigationStack {
            VStack {
                TitleAndSubTitle(title: "Choose an identity",
                                 subTitle: "You could modify this later in app settings",
                                 style: .caption)
                List {
                    ForEach(userTypeDescription.sorted(by: {$0.key.hashValue < $1.key.hashValue}), id:\.key.hashValue) { userType, description in
                        Button {
                            withAnimation {
                                userTypeSheet = false
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
                    userTypeSheet = false
                } label: {
                    Text("Skip for now")
                }
                .buttonStyle(BigButtonStyle())
            }
            .padding()
            .navigationTitle("Before we continue...")
        }
    }
    
    init(userTypeSheet: Binding<Bool>? = nil) {
        if let userTypeSheet {
            self._userTypeSheet = userTypeSheet
        } else {
            self._userTypeSheet = .constant(false)
        }
    }
}
