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

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Spacer()
                        .frame(height: 30)
                    HStack {
                        Spacer()
                        Image("Icon")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .onTapGesture(count: 5) {
                                UIPasteboard.general.string = String(describing: Array(userDefaults.dictionaryRepresentation()))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 4)
                        Spacer()
                        Image(systemName: "link")
                            .resizable()
                            .frame(width: 33, height: 33)
                        Spacer()
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.crop.square.filled.and.at.rectangle")
                                .resizable()
                                .frame(width: 40, height: 30)
                                .foregroundColor(Color.secondary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)
                        Spacer()
                    }

                    Spacer()
                        .frame(height: 30)

                    Text("casHint")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                    Spacer()
                        .frame(height: 30)

                    HStack(alignment: .top) {
                        Text("Username:")
                            .bold()
                        VStack(alignment: .leading) {
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
                                .padding(.vertical, 0)
                        }
                        .frame(width: 220)
                    }

                    HStack(alignment: .top) {
                        Text("Password:")
                            .bold()
                        VStack(alignment: .leading) {
                            SecureField("Password", text: $passportPassword)
                                .focused($foucusField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit {
                                    checkAndLogin()
                                }
                                .padding(.horizontal, 3)
                            Divider()
                        }
                        .frame(width: 220)
                    }

                    Spacer()

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
                }
                .padding()
                .padding(.top)
            }
            .padding(.horizontal)
            .alert("Login Failed".localized, isPresented: $showFailedAlert, actions: {}, message: {
                Text("Double check your username and password".localized)
            })
            .alert("Login Success".localized, isPresented: $showSuccessAlert, actions: {}, message: {
                Text("You're good to go".localized)
            })
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
