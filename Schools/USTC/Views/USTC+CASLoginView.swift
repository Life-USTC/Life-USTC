//
//  CASLoginView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

extension View {
    fileprivate func customizeShape() -> some View {
        frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 4)
    }
}

struct USTCCASLoginView: View {
    @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate
    @LoginClient(.ustcCAS) var ustcCasClient: UstcCasClient

    @State var presenterInjected = true
    @StateObject var ustcCASViewModel = UstcCasViewModel.shared
    @State var showFailedAlert = false
    @State var showSuccessAlert = false
    @State var failedMessage: LocalizedStringKey = "Double check your username and password"
    enum Field: Int, Hashable {
        case username
        case password
        case studentType
    }
    @FocusState var focusField: Field?

    var title: LocalizedStringKey? = "CAS Settings"
    var onSuccess: (() -> Void)? = nil

    var body: some View {
        VStack {
            HStack(spacing: 50) {
                Image("Icon")
                    .resizable()
                    .customizeShape()
                Image(systemName: "link")
                    .resizable()
                    .frame(width: 33, height: 33)
                Image(systemName: "person.crop.square.filled.and.at.rectangle")
                    .resizable()
                    .foregroundColor(.init(hex: "#004075"))
                    .frame(width: 40, height: 30)
                    .background {
                        Color.white
                            .customizeShape()
                    }
            }
            .padding(.vertical, 30)

            Text("casHint")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.bottom, 30)

            VStack(spacing: 20) {
                HStack(alignment: .center) {
                    Text("Username:")
                        .font(.system(.body, design: .monospaced, weight: .bold))
                    Spacer()
                    VStack {
                        TextField(
                            "Username",
                            text: $ustcCASViewModel.inputUsername
                        )
                        .focused($focusField, equals: .username)
                        .onSubmit {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.1
                            ) {
                                focusField = .password
                            }
                        }
                        .submitLabel(.next)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        Divider()
                    }
                    .frame(width: 200)
                }
                HStack(alignment: .center) {
                    Text("Password:")
                        .font(.system(.body, design: .monospaced, weight: .bold))
                    Spacer()
                    VStack {
                        SecureField(
                            "Password",
                            text: $ustcCASViewModel.inputPassword
                        )
                        .focused($focusField, equals: .password)
                        .onSubmit {
                            focusField = .studentType
                        }
                        .submitLabel(.next)
                        Divider()
                    }
                    .frame(width: 200)
                }

                HStack(alignment: .center) {
                    Text("Type:")
                        .font(.system(.body, design: .monospaced, weight: .bold))
                    Spacer()
                    Picker(selection: $ustcStudentType, label: Text("Student Type")) {
                        Text("Undergraduate")
                            .tag(USTCStudentType.undergraduate)
                        Text("Graduate")
                            .tag(USTCStudentType.graduate)
                    }
                    .focused($focusField, equals: .password)
                    .submitLabel(.done)
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }

            Spacer()

            Button {
                checkAndLogin()
            } label: {
                Text("Check & Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.accentColor)
                    }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 30)
        .alert(
            "Login Failed",
            isPresented: $showFailedAlert,
            actions: {},
            message: {
                Text(failedMessage)
            }
        )
        .alert(
            "Login Success",
            isPresented: $showSuccessAlert,
            actions: {},
            message: {
                Text("You're good to go")
            }
        )
        .if(title != nil) { view in
            view.navigationTitle(title!)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    func checkAndLogin() {
        Task {
            do {
                let result = try await ustcCASViewModel.checkAndLogin()
                if result {
                    showSuccessAlert = true

                    // close after 1 second
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + .seconds(1)
                    ) {
                        showSuccessAlert = false
                        if let onSuccess = onSuccess {
                            onSuccess()
                        }
                    }
                    return
                }

                failedMessage = "Double check your username and password"
                showFailedAlert = true
            } catch {
                failedMessage = LocalizedStringKey(error.localizedDescription)
                showFailedAlert = true
            }
        }
    }
}
