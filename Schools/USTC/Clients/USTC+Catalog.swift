//
//  UstcCatalog.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/15.
//

import SwiftUI
import SwiftyJSON

class UstcCatalogClient: LoginClientProtocol {
    static var shared = UstcCatalogClient()

    var token: String = ""

    func login() async throws -> Bool {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catalog.ustc.edu.cn/get_token")!)

        if let token = try? JSON(data: data)["access_token"].string {
            self.token = token
            return true
        }
        return false
    }

    init() {}
}

extension LoginClients {
    var ustcCatalog: UstcCatalogClient {
        UstcCatalogClient.shared
    }
}
