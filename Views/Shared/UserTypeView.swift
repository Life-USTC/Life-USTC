//
//  NewUser.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

enum UserTypeViewShowType {
    case sheet
    case newPage
}

struct UserTypeView: View {
    @AppStorage("userType") var userType: UserType?
    @Binding var userTypeSheet: Bool

    var showType: UserTypeViewShowType

    var mainView: some View {
        List {
            ForEach(UserType.allCases, id: \.rawValue) { userType in
                Button {
                    withAnimation {
                        self.userType = userType
                        if showType == .sheet {
                            userTypeSheet = false
                        }
                    }
                } label: {
                    HStack {
                        TitleAndSubTitle(title: String(describing: userType).capitalized,
                                         subTitle: userType.representingString,
                                         style: .substring)
                        Spacer()
                        if showType == .sheet {
                            Image(systemName: "chevron.right")
                        } else if userType == self.userType {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }

    var body: some View {
        if showType == .sheet {
            NavigationStack {
                VStack {
                    TitleAndSubTitle(title: "Choose an identity",
                                     subTitle: "You could modify this later in app settings",
                                     style: .caption)
                    mainView
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
                .navigationBarTitleDisplayMode(.large)
            }
        } else {
            NavigationStack {
                mainView
            }
            .navigationTitle("Change User Type")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    init(userTypeSheet: Binding<Bool>? = nil) {
        if let userTypeSheet {
            _userTypeSheet = userTypeSheet
            showType = .sheet
        } else {
            _userTypeSheet = .constant(false)
            showType = .newPage
        }
    }
}
