//
//  CASLoginView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct USTCCASLoginView: View {
    static func sheet(isPresented: Binding<Bool>) -> USTCCASLoginView {
        USTCCASLoginView(
            title: "One more step...",
            isInSheet: true,
            casLoginSheet: isPresented
        )
    }

    static var newPage = USTCCASLoginView(casLoginSheet: .constant(false))

    var title: LocalizedStringKey = "CAS Settings"
    var isInSheet = false

    enum Field: Int, Hashable {
        case username
        case password
    }

    @StateObject var ustcCASVoewModel = UstcCasViewModel.shared
    @Binding var casLoginSheet: Bool  // used to signal the sheet to close
    @State var showFailedAlert = false
    @State var showSuccessAlert = false
    @FocusState var foucusField: Field?

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Spacer().frame(height: 30)
                    HStack {
                        Spacer()
                        Image("Icon").resizable().frame(width: 80, height: 80)
                            .onTapGesture(count: 5) {
                                UIPasteboard.general.string = String(
                                    describing: Array(
                                        UserDefaults.appGroup
                                            .dictionaryRepresentation()
                                    )
                                )
                            }.clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 4)
                        Spacer()
                        Image(systemName: "link").resizable().frame(
                            width: 33,
                            height: 33
                        )
                        Spacer()
                        ZStack {
                            Rectangle().fill(Color.white).frame(
                                width: 80,
                                height: 80
                            )
                            Image(
                                systemName:
                                    "person.crop.square.filled.and.at.rectangle"
                            ).resizable().frame(width: 40, height: 30)
                                .foregroundColor(Color.secondary)
                        }.clipShape(RoundedRectangle(cornerRadius: 20)).shadow(
                            radius: 4
                        )
                        Spacer()
                    }

                    Spacer().frame(height: 30)

                    Text("casHint").font(.caption).bold().foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                    Spacer().frame(height: 30)

                    HStack(alignment: .top) {
                        Text("Username:").bold()
                        VStack(alignment: .leading) {
                            TextField(
                                "Username",
                                text: $ustcCASVoewModel.inputUsername
                            ).focused($foucusField, equals: .username).onSubmit
                            {
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.1
                                ) { foucusField = .password }
                            }.submitLabel(.next).autocorrectionDisabled(true)
                                .keyboardType(.asciiCapable)

                            Divider().padding(.vertical, 0)
                        }.frame(width: 220)
                    }

                    HStack(alignment: .top) {
                        Text("Password:").bold()
                        VStack(alignment: .leading) {
                            SecureField(
                                "Password",
                                text: $ustcCASVoewModel.inputPassword
                            ).focused($foucusField, equals: .password)
                                .submitLabel(.done).onSubmit { checkAndLogin() }
                                .padding(.horizontal, 3)
                            Divider()
                        }.frame(width: 220)
                    }

                    Spacer()

                    Button {
                        checkAndLogin()
                    } label: {
                        Text("Check & Login").foregroundColor(.white).padding()
                            .frame(maxWidth: .infinity).background {
                                RoundedRectangle(cornerRadius: 25).fill(
                                    Color.accentColor
                                )
                            }.frame(maxWidth: .infinity)
                    }.keyboardShortcut(.defaultAction)
                }.padding().padding(.top)
            }.padding(.horizontal).alert(
                "Login Failed".localized,
                isPresented: $showFailedAlert,
                actions: {},
                message: {
                    Text("Double check your username and password".localized)
                }
            ).alert(
                "Login Success".localized,
                isPresented: $showSuccessAlert,
                actions: {},
                message: { Text("You're good to go".localized) }
            ).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        }
    }

    private func checkAndLogin() {
        Task {
            do {
                let result = try await ustcCASVoewModel.checkAndLogin()
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

struct USTCCASLoginView_Previews: PreviewProvider {
    static var previews: some View {
        USTCCASLoginView.newPage
        #if os(iOS)
        USTCCASLoginView.sheet(isPresented: .constant(false))
        #endif
    }
}
