//
//  UserTypeView.swift
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
                        VStack(alignment: .leading) {
                            Text(String(describing: userType).capitalized)
                                .font(.body)
                                .bold()
                                .padding(.bottom, 1)
                            Text(userType.caption)
                                .font(.caption)
                        }
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
        .scrollContentBackground(.hidden)
    }

    var body: some View {
        if showType == .sheet {
            NavigationStack {
                VStack {
                    VStack(alignment: .leading) {
                        Text("Choose an identity")
                            .font(.title2)
                            .bold()
                        Text("You could modify this later in app settings")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .bold()
                    }
                    mainView
                        .listStyle(.plain)
                    Spacer()
                    Button {
                        userTypeSheet = false
                    } label: {
                        Text("Skip for now")
                            .foregroundColor(.white)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor)
                                    .frame(width: 250, height: 50)
                            }
                            .padding()
                    }
                }
                .padding()
                .navigationBarTitle("Before we continue...", displayMode: .inline)
            }
        } else {
            mainView
                .navigationBarTitle("Change User Type", displayMode: .inline)
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
