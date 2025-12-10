//
//  USTC+Blackboard.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import SwiftSoup
import SwiftUI

/// USTC Undergraduate Academic Affairs System
class USTCBlackboardClient: LoginClientProtocol {
    static let shared = USTCBlackboardClient()

    @LoginClient(.ustcCAS) var casClient: USTCCASClient
    var session: URLSession = .shared

    override func login() async throws -> Bool {
        if !(try await _casClient.requireLogin()) {
            throw BaseError.runtimeError("UstcCAS Not logined")
        }

        let (data, res) = try await session.data(
            from: URL(
                string:
                    "https://passport.ustc.edu.cn/login?service=https%3a%2f%2fwww.bb.ustc.edu.cn%2fwebapps%2fbb-SSOIntegrationDemo-BBLEARN%2fexecute%2fauthValidate%2fcustomLogin%3freturnUrl%3dhttp%3a%2f%2fwww.bb.ustc.edu.cn%2fwebapps%2fportal%2fframeset.jsp%26authProviderId%3d_103_1"
            )!
        )

        // if a <a href> presents, follow it:
        let html = String(data: data, encoding: .utf8) ?? ""
        let document = try SwiftSoup.parse(html)
        if let linkElement = try document.select("a").first(),
            let href = try? linkElement.attr("href"),
            href.starts(with: try! Regex("login\\.php")),
            let linkURL = URL(string: "https://www.bb.ustc.edu.cn/nginx_auth/\(href)")
        {
            let (linkData, _) = try await session.data(from: linkURL)

            // find and click again
            let linkHTML = String(data: linkData, encoding: .utf8) ?? ""
            let linkDocument = try SwiftSoup.parse(linkHTML)
            if let finalLinkElement = try linkDocument.select("a").first(),
                let finalHref = try? finalLinkElement.attr("href"),
                let finalLinkURL = URL(string: finalHref)
            {
                let (_) = try await session.data(from: finalLinkURL)
            }
        }

        return res.url == URL(
            string:
                "https://www.bb.ustc.edu.cn/webapps/portal/execute/tabs/tabAction?tab_tab_group_id=_1_1"
        )!
    }
}

extension LoginClientProtocol {
    static var ustcBlackboard = USTCBlackboardClient.shared
}
