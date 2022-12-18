//
//  LoginSheet.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

var mainUstcCasClient: any CasClient = UstcCasClient(username: "", password: "")

struct LoginSheet: View {
    @AppStorage("passportUsername") var passportUsername: String = ""
    @AppStorage("passportPassword") var passportPassword: String = ""
    @Binding var loginSheet: Bool
    @State var showFailedAlert = false
    
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
                    loginSheet = false
                }
            } label: {
                Text("Skip for Now")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TitleAndSubTitle(title: "Input USTC CAS username & password",
                                 subTitle: "",
                                 style: .caption)
                
                Text("""
                        This service is brought to you by USTC CAS server, not this app.
                        For more information, see Settings > Legal > Disclaimer
                        """)
                .font(.caption)
                .foregroundColor(.secondary)
                .bold()
                Spacer()
                inputForm
                Spacer()
            }
            .alert("Login Failed", isPresented: $showFailedAlert, actions: {}, message: {
                Text("Double check your username and password")
            })
            .padding()
            .navigationTitle("One more Step")
        }
    }
    
    private func checkAndLogin() {
        mainUstcCasClient = UstcCasClient(username: passportUsername, password: passportPassword)
        if mainUstcCasClient.checkLogined() {
            loginSheet = false
        } else {
            showFailedAlert = true
        }
    }
    
    init(_ binding: Binding<Bool>) {
        self._loginSheet = binding
    }
}

extension ContentView {
    func loadMainUser() {
        mainUstcCasClient = UstcCasClient(username: passportUsername, password: passportPassword)
        DispatchQueue.main.async {
            let result = mainUstcCasClient.loginToCAS()
            if result {
                loginSheet = true
            }
        }
        if passportUsername == "" && passportPassword == "" {
            loginSheet = true
        }
    }
}
