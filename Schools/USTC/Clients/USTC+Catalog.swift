//
//  UstcCatalog.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/15.
//

import SwiftUI
import SwiftyJSON

class UstcCatalogClient: LoginClientProtocol {
    static let shared = UstcCatalogClient()

    @AppStorage("UstcCatalogClient_token", store: .appGroup) var token: String = ""

    override func login() async throws -> Bool {
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "https://catalog.ustc.edu.cn/get_token")!
        )

        if let token = try? JSON(data: data)["access_token"].string {
            self.token = token
            return true
        }
        return false
    }
}

extension LoginClientProtocol {
    static let ustcCatalog = UstcCatalogClient.shared
}
