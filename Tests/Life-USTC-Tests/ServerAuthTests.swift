import XCTest
@testable import Life_USTC

final class ServerAuthTests: XCTestCase {
    func testAuthorizationCallbackIsBoundToStateAndRedirect() throws {
        let valid = URL(string: "dev.tiankaima.life-ustc://auth/callback?code=issued-code&state=expected")!
        XCTAssertEqual(try ServerAuth.authorizationCode(from: valid, expectedState: "expected"), "issued-code")
        for raw in [
            "dev.tiankaima.life-ustc://auth/callback?code=issued-code",
            "dev.tiankaima.life-ustc://auth/callback?code=issued-code&state=other",
            "dev.tiankaima.life-ustc://auth/callback?code=issued-code&state=expected&state=other",
            "dev.tiankaima.life-ustc://wrong/callback?code=issued-code&state=expected",
            "dev.tiankaima.life-ustc://auth/wrong?code=issued-code&state=expected",
            "dev.tiankaima.life-ustc://auth:123/callback?code=issued-code&state=expected",
            "dev.tiankaima.life-ustc://user@auth/callback?code=issued-code&state=expected",
            "dev.tiankaima.life-ustc://auth/callback?code=issued-code&code=other&state=expected",
            "dev.tiankaima.life-ustc://auth/callback?code=&state=expected",
            "dev.tiankaima.life-ustc://auth/callback?error=access_denied&code=issued-code&state=expected",
        ] {
            XCTAssertThrowsError(try ServerAuth.authorizationCode(from: URL(string: raw), expectedState: "expected"))
        }
    }

    func testPKCEUsesRFC7636S256Vector() {
        XCTAssertEqual(
            ServerAuth.generateCodeChallenge(from: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    func testNewAuthorizationClearsPreviousRefreshToken() throws {
        let tokens = MockTokenStore()
        tokens.refreshToken = "previous-owner-refresh"
        let client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://test.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"new-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: client.sessionRevision)
        XCTAssertEqual(tokens.accessToken, "new-owner")
        XCTAssertTrue(tokens.refreshToken.isEmpty)
    }

    func testLateAuthorizationCannotRestoreSignedOutSession() throws {
        let tokens = MockTokenStore()
        let client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://test.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
        let revision = client.sessionRevision
        client.clearTokens()
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"late-token","token_type":"Bearer"}"#.utf8))
        XCTAssertThrowsError(try client.acceptAuthorization(authorization, expectedRevision: revision))
        XCTAssertTrue(tokens.accessToken.isEmpty)
    }
}
