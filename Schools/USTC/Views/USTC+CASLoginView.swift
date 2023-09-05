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
    enum Field: Int, Hashable {
        case username
        case password
    }

    @Binding var casLoginSheet: Bool  // used to signal the sheet to close
    @StateObject var ustcCASViewModel = UstcCasViewModel.shared
    @State var showFailedAlert = false
    @State var showSuccessAlert = false
    @FocusState var foucusField: Field?

    var title: LocalizedStringKey = "CAS Settings"
    var isInSheet = false

    var iconView: some View {
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
    }

    var formView: some View {
        VStack {
            HStack(alignment: .top) {
                Text("Username:")
                    .font(.system(.body, design: .monospaced, weight: .bold))
                VStack(alignment: .leading) {
                    TextField(
                        "Username",
                        text: $ustcCASViewModel.inputUsername
                    )
                    .focused($foucusField, equals: .username)
                    .onSubmit {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.1
                        ) {
                            foucusField = .password
                        }
                    }
                    .submitLabel(.next)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)

                    Divider()
                }
                .frame(width: 220)
            }

            HStack(alignment: .top) {
                Text("Password:")
                    .font(.system(.body, design: .monospaced, weight: .bold))
                VStack(alignment: .leading) {
                    SecureField(
                        "Password",
                        text: $ustcCASViewModel.inputPassword
                    )
                    .focused($foucusField, equals: .password)
                    .onSubmit {
                        checkAndLogin()
                    }
                    .submitLabel(.done)

                    Divider()
                }
                .frame(width: 220)
            }
        }
    }

    var loginButton: some View {
        Button {
            checkAndLogin()
        } label: {
            Text("Check & Login").foregroundColor(.white).padding()
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.accentColor)
                }
                .frame(maxWidth: .infinity)
        }
        .keyboardShortcut(.defaultAction)
    }

    var body: some View {
        NavigationStack {
            VStack {
                iconView
                    .padding(.vertical, 30)

                Text("casHint")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 30)

                formView

                Spacer()

                loginButton
            }
            .padding([.top, .horizontal])
            .alert(
                "Login Failed".localized,
                isPresented: $showFailedAlert,
                actions: {},
                message: {
                    Text("Double check your username and password".localized)
                }
            )
            .alert(
                "Login Success".localized,
                isPresented: $showSuccessAlert,
                actions: {},
                message: { Text("You're good to go".localized) }
            )
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        }
    }

    func checkAndLogin() {
        Task {
            do {
                let result = try await ustcCASViewModel.checkAndLogin()
                if result, isInSheet {
                    showSuccessAlert = true

                    // close after 1 second
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + .seconds(1)
                    ) {
                        showSuccessAlert = false
                        casLoginSheet = false
                    }
                    return
                } else if result {
                    showSuccessAlert = true
                    return
                }

                showFailedAlert = true
            } catch { showFailedAlert = true }
        }
    }
}

extension USTCCASLoginView {
    static func sheet(isPresented: Binding<Bool>) -> USTCCASLoginView {
        USTCCASLoginView(
            casLoginSheet: isPresented,
            title: "One more step...",
            isInSheet: true
        )
    }

    static var newPage = USTCCASLoginView(casLoginSheet: .constant(false))
}

struct USTCCASLoginView_Previews: PreviewProvider {
    static var previews: some View {
        USTCCASLoginView.newPage
        USTCCASLoginView.sheet(isPresented: .constant(false))
    }
}
