//
//  CASLoginView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct CASLoginView: View {
    static func sheet(isPresented: Binding<Bool>) -> CASLoginView {
        CASLoginView(casLoginSheet: isPresented, isInSheet: true, title: "One more step...")
    }

    static var newPage = CASLoginView(casLoginSheet: .constant(false))

    // abstract from LoginSheet, some variables are subject to change though
    @AppStorage("passportUsername", store: userDefaults) var passportUsername: String = ""
    @AppStorage("passportPassword", store: userDefaults) var passportPassword: String = ""

    @Binding var casLoginSheet: Bool // used to signal the sheet to close
    var isInSheet = false

    var title: LocalizedStringKey = "CAS Settings"

    @State var showFailedAlert = false
    @State var showSuccessAlert = false

    enum Field: Int, Hashable {
        case username
        case password
    }

    @FocusState var foucusField: Field?

    var inputForm: some View {
        VStack {
            Text("Login to USTC CAS")
                .bold()
                .foregroundColor(.accentColor)
                .hStackLeading()
            VStack {
                Image("Icon.ustc")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 70)

                Spacer()
                    .frame(height: 30)

                TextField("Username", text: $passportUsername)
                    .focused($foucusField, equals: .username)
                    .onSubmit {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            foucusField = .password
                        }
                    }
                    .submitLabel(.next)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)

                Divider()

                SecureField("Password", text: $passportPassword)
                    .focused($foucusField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        checkAndLogin()
                    }

                Divider()

                Spacer()
                    .frame(height: 50)

                Button {
                    checkAndLogin()
                } label: {
                    Text("Check & Login")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.accentColor)
                        }
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)

                Text("casHint")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)
                    .padding(.top)
            }
            .padding()
            .padding(.top)
            .clipShape(
                RoundedRectangle(cornerRadius: 15)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray)
                    .opacity(0.6)
            )
        }
        .padding(.horizontal)
        .alert("Login Failed".localized, isPresented: $showFailedAlert, actions: {}, message: {
            Text("Double check your username and password".localized)
        })
        .alert("Login Success".localized, isPresented: $showSuccessAlert, actions: {}, message: {
            Text("You're good to go".localized)
        })
    }

    var body: some View {
        NavigationStack {
            inputForm
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func checkAndLogin() {
        Task {
            await UstcCasClient.shared.clearLoginStatus()
            await URLSession.shared.reset()
            let result = try await UstcCasClient.shared.login(undeterimined: true)
            if result {
                if isInSheet {
                    showSuccessAlert = true
                    // close after 1 second
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

struct CASLoginView_Previews: PreviewProvider {
    static var previews: some View {
        CASLoginView.newPage
#if os(iOS)
        CASLoginView.sheet(isPresented: .constant(false))
#endif
    }
}
