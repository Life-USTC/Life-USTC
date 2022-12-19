//
//  LoginSheet.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

var mainUstcCasClient: any CasClient = UstcCasClient(username: "", password: "")

struct CASLoginView: View {
    // abstract from LoginSheet, some variables are subject to change though
    @AppStorage("passportUsername") var passportUsername: String = ""
    @AppStorage("passportPassword") var passportPassword: String = ""
    
    @Binding var casLoginSheet: Bool // used to signal the sheet to close
    var isInSheet = false
    
    var title: LocalizedStringKey = "CAS Settings"
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
            Button(action: checkAndLogin, label: {Text("Check & Login")})
            
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
        }
    }
    
    private func checkAndLogin() {
        mainUstcCasClient.update(username: passportUsername, password: passportPassword)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result = mainUstcCasClient.loginToCAS()
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
    
    init(casLoginSheet: Binding<Bool>? = nil, title: LocalizedStringKey? = nil, displayMode: NavigationBarItem.TitleDisplayMode? = nil, isInSheet: Bool? = nil) {
        if let casLoginSheet {
            self._casLoginSheet = casLoginSheet
        } else {
            self._casLoginSheet = .constant(false)
        }
        if let title {
            self.title = title
        }
        if let displayMode {
            self.displayMode = displayMode
        }
        if let isInSheet {
            self.isInSheet = isInSheet
        }
    }
    
}


extension ContentView {
    func loadMainUser() {
        mainUstcCasClient = UstcCasClient(username: passportUsername, password: passportPassword)
        DispatchQueue.main.async {
            let result = mainUstcCasClient.loginToCAS()
            if !result {
                casLoginSheet = true
            }
        }
        if passportUsername == "" && passportPassword == "" {
            casLoginSheet = true
        }
    }
}
