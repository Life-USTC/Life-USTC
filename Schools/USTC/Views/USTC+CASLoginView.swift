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
    @AppStorage("appShouldPresentDemo", store: .appGroup) var appShouldPresentDemo: Bool = false
    @AppStorage("ustcStudentType", store: .appGroup) var ustcStudentType: USTCStudentType = .graduate

    enum Field: Int, Hashable {
        case username
        case password
        case deviceID
        case fingerPrint
    }

    @Binding var casLoginSheet: Bool  // used to signal the sheet to close
    @StateObject var ustcCASViewModel = UstcCasViewModel.shared
    @State var showFailedAlert = false
    @State var showSuccessAlert = false
    @State var failedMessage = ""
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
                    .focused($foucusField, equals: .password)
                    .onSubmit {
                        foucusField = .deviceID
                    }
                    .submitLabel(.done)
                    Divider()
                }
                .frame(width: 200)
            }
            HStack(alignment: .center) {
                Text("DeviceID:")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                Spacer()
                VStack {
                    TextField(
                        "DeviceID",
                        text: $ustcCASViewModel.inputDeviceID
                    )
                    .focused($foucusField, equals: .deviceID)
                    .onSubmit {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.1
                        ) {
                            foucusField = .fingerPrint
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
                Text("Fingerprint:")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                Spacer()
                VStack {
                    TextField(
                        "Fingerprint",
                        text: $ustcCASViewModel.inputFingerPrint
                    )
                    .focused($foucusField, equals: .fingerPrint)
                    .onSubmit {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.1
                        ) {
                            checkAndLogin()
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
                Text("Type:")
                    .font(.system(.body, design: .monospaced, weight: .bold))
                Spacer()
                Picker(selection: $ustcStudentType, label: Text("Student Type")) {
                    Text("Undergraduate")
                        .tag(USTCStudentType.undergraduate)
                    Text("Graduate")
                        .tag(USTCStudentType.graduate)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if !isInSheet {
                HStack {
                    Text("Close and reopen the app to take effect.")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            
            HStack {
                Text("For more information, visit <https://notes.tiankaima.dev/blog/xzkd-new-tokens/>")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 30)
    }

    var loginButton: some View {
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
                    Text(failedMessage.localized)
                }
            )
            .alert(
                "Login Success".localized,
                isPresented: $showSuccessAlert,
                actions: {},
                message: {
                    Text("You're good to go")
                }
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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

                failedMessage = "Double check your username and password".localized
                showFailedAlert = true
            } catch {
                failedMessage = error.localizedDescription
                showFailedAlert = true
            }
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
