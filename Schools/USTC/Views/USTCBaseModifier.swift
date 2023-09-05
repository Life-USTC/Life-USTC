//
//  USTCBaseModifier.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

struct USTCBaseModifier: ViewModifier {
    @LoginClient(.ustcCAS) var casClient: UstcCasClient
    @LoginClient(.ustcUgAAS) var ugAASClient: UstcUgAASClient

    @State var casLoginSheet: Bool = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: $casLoginSheet) {
            USTCCASLoginView.sheet(isPresented: $casLoginSheet)
        }
        .onAppear(perform: onLoadFunction)
    }

    func onLoadFunction() {
        Task {
            if appShouldPresentDemo {
                return
            }

            _casClient.clearLoginStatus()
            _ugAASClient.clearLoginStatus()

            if casClient.precheckFails {
                casLoginSheet = true
                return
            }
            // if the login result fails, present the user with the sheet.
            casLoginSheet = try await !_casClient.requireLogin()
        }
    }
}
