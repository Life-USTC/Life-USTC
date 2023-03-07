//
//  CASLoginView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct CASLoginView: View {
    static func sheet(isPresented: Binding<Bool>) -> CASLoginView {
        CASLoginView(casLoginSheet: isPresented, isInSheet: true, title: "One more step...", displayMode: .large)
    }

    static var newPage = CASLoginView(casLoginSheet: .constant(false))

    // abstract from LoginSheet, some variables are subject to change though
    @AppStorage("passportUsername", store: userDefaults) var passportUsername: String = ""
    @AppStorage("passportPassword", store: userDefaults) var passportPassword: String = ""

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
        VStack {
            Form {
                HStack {
#if os(iOS)
                    Text("Username:")
#endif
                    TextField("Username", text: $passportUsername)
                        .focused($foucusField, equals: .username)
                        .onSubmit {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                foucusField = .password
                            }
                        }
                        .submitLabel(.next)
                        .autocorrectionDisabled(true)
#if os(iOS)
                        .keyboardType(.asciiCapable)
#endif
                    Spacer()
                }
                HStack {
#if os(iOS)
                    Text("Password:")
#endif
                    SecureField("Password", text: $passportPassword)
                        .focused($foucusField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit {
                            checkAndLogin()
                        }
                    Spacer()
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)

            HStack(spacing: 45){
                if isInSheet {
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            casLoginSheet = false
                        }
                    } label: {
                        Label("Skip for now", systemImage: "xmark")
                            .padding()
                            .labelStyle(.iconOnly)
                            .background {
                                Circle()
                                    .fill(Color.gray.opacity(0.25))
                            }
                    }
                }
                
                Button {
                    checkAndLogin()
                } label: {
                    Text("Check & Login")
                        .foregroundColor(.white)
                        .padding()
                        .padding([.leading, .trailing], 35)
                        .background{
                            RoundedRectangle(cornerRadius: 50)
                            .fill(Color.accentColor)
                        }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Input USTC CAS username & password")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 1)
                Text("casHint")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.gray)

                inputForm
            }
            .alert("Login Failed".localized, isPresented: $showFailedAlert, actions: {}, message: {
                Text("Double check your username and password".localized)
            })
            .alert("Login Success".localized, isPresented: $showSuccessAlert, actions: {}, message: {
                Text("You're good to go".localized)
            })
            .padding()
            .navigationBarTitle(title, displayMode: displayMode)
        }
    }

    private func checkAndLogin() {
        Task {
            let result = try await UstcCasClient.shared.login(undeterimined: true)
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

struct CASLoginView_Previews: PreviewProvider {
    static var previews: some View {
        CASLoginView.newPage
#if os(iOS)
        CASLoginView.sheet(isPresented: .constant(false))
#endif
    }
}
