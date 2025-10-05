//
//  USTC+Blackboard.swift
//  学在科大
//
//  Created by TianKai Ma on 2023/12/1.
//

import SwiftSoup
import SwiftUI
import SwiftyJSON
import WidgetKit

private let urlA = URL(
    string:
        "https://www.bb.ustc.edu.cn/webapps/bb-SSOIntegrationDemo-BBLEARN/execute/authValidate/customLogin?returnUrl=http://www.bb.ustc.edu.cn/webapps/portal/frameset.jsp&authProviderId=_103_1"
)!
private let urlB = URL(
    string:
        "https://passport.ustc.edu.cn/login?service=https%3a%2f%2fwww.bb.ustc.edu.cn%2fwebapps%2fbb-SSOIntegrationDemo-BBLEARN%2fexecute%2fauthValidate%2fcustomLogin%3freturnUrl%3dhttp%3a%2f%2fwww.bb.ustc.edu.cn%2fwebapps%2fportal%2fframeset.jsp%26authProviderId%3d_103_1"
)!
private let urlC = URL(
    string:
        "https://www.bb.ustc.edu.cn/webapps/portal/execute/tabs/tabAction?tab_tab_group_id=_1_1"
)!

/// USTC Undergraduate Academic Affairs System
class UstcBlackboardClient: LoginClientProtocol {
    static let shared = UstcBlackboardClient()

    @LoginClient(.ustcCAS) var casClient: UstcCasClient
    var session: URLSession = .shared

    override func login() async throws -> Bool {

        // jw.ustc.edu.cn login.
        _ = try await session.data(from: urlA)
        _ = try await casClient.loginToCAS(urlB)

        // now try login url, see if that directs to home page
        var request = URLRequest(url: urlB)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)

        return (response.url == urlC)
    }
}

extension LoginClientProtocol {
    static var ustcBlackboard = UstcBlackboardClient.shared
}
