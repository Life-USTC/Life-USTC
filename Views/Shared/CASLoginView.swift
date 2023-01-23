//
//  CASLoginView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct CASLoginView: View {
    // abstract from LoginSheet, some variables are subject to change though
    @AppStorage("passportUsername", store: userDefaults) var passportUsername: String = ""
    @AppStorage("passportPassword", store: userDefaults) var passportPassword: String = ""

    @Binding var casLoginSheet: Bool // used to signal the sheet to close
    var isInSheet = false

    var title: String = "CAS Settings"
    var displayMode: NavigationBarItem.TitleDisplayMode = .inline

    @State var showFailedAlert = false
    @State var showSuccessAlert = false

    enum Field: Int, Hashable {
        case username
        case password
    }

    @FocusState var foucusField: Field?

    var inputForm: some View {
        Form {
            HStack {
                Text("Username:")
                Spacer()
                TextField("Username", text: $passportUsername)
                    .focused($foucusField, equals: .username)
                    .onSubmit {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            foucusField = .password
                        }
                    }
                    .submitLabel(.next)
                    .keyboardType(.asciiCapable)
                Spacer()
            }
            HStack {
                Text("Password:")
                Spacer()
                SecureField("Password", text: $passportPassword)
                    .focused($foucusField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        checkAndLogin()
                    }
                Spacer()
            }
            Button(action: checkAndLogin, label: { Text("Check & Login") })

            Button {
                passportUsername = ""
                passportPassword = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    casLoginSheet = false
                }
            } label: {
                Text("Skip for now")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }

    var body: some View {
        NavigationStack {
            VStack {
                TitleAndSubTitle(title: "Input USTC CAS username & password",
                                 subTitle: "casHint",
                                 style: .caption)
                Spacer()
                inputForm
                Spacer()
            }
            .alert("Login Failed", isPresented: $showFailedAlert, actions: {}, message: {
                Text("Double check your username and password")
            })
            .alert("Login Success", isPresented: $showSuccessAlert, actions: {}, message: {
                Text("You're good to go")
            })
            .padding()
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(displayMode)
        }
    }

    private func checkAndLogin() {
        UstcCasClient.main.update(username: passportUsername, password: passportPassword)
        _ = Task {
            let result = try await UstcCasClient.main.loginToCAS()
            if result {
                if isInSheet {
                    showSuccessAlert = true
                    // autoclose... dispatch within another dispatch
                    // real fun...
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        showSuccessAlert = false
                        casLoginSheet = false
                    }
                } else {
                    showSuccessAlert = true
                }
            } else {
                showFailedAlert = true
            }
        }
    }
}
