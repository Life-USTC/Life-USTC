import XCTest
@testable import Life_USTC

final class ServerSessionTests: XCTestCase {
    private var client: ServerClient!
    private var tokens: MockTokenStore!

    override func setUp() {
        MockURLProtocol.reset()
        tokens = MockTokenStore()
        tokens.accessToken = "first-owner"
        client = ServerClient(configuration: ServerClientConfiguration(
            baseURL: URL(string: "https://first.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        UserDefaults.standard.removeObject(forKey: "serverBaseURL")
        client = nil
        tokens = nil
    }

    func testDoesNotReturnPreviousOwnerResponseAfterLogout() async throws {
        let client = self.client!
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"first-owner","name":"Private name"}"#.utf8))
        }
        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("A response belonging to the logged-out account must be discarded")
        } catch is CancellationError {
            XCTAssertTrue(tokens.accessToken.isEmpty)
        }
    }

    func testDoesNotInstallRefreshTokenAfterBackendChange() async throws {
        let client = self.client!
        tokens.refreshToken = "first-refresh"
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.hasSuffix("/token") == true {
                client.reconfigure(baseURL: URL(string: "https://second.example")!)
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Data(#"{"access_token":"old-owner-new-token","refresh_token":"old-owner-refresh","token_type":"Bearer"}"#.utf8))
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("A refresh from a former backend must not be accepted")
        } catch is CancellationError {
            XCTAssertEqual(client.baseURL.host, "second.example")
            XCTAssertTrue(tokens.accessToken.isEmpty)
            XCTAssertTrue(tokens.refreshToken.isEmpty)
            XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.url?.host == "second.example" })
        }
    }

    func testFailedRefreshCannotClearNewAuthorization() async throws {
        let client = self.client!
        tokens.refreshToken = "first-refresh"
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.hasSuffix("/token") == true {
                let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
                    Data(#"{"access_token":"second-owner","refresh_token":"second-refresh","token_type":"Bearer"}"#.utf8))
                try client.acceptAuthorization(authorization, expectedRevision: client.sessionRevision)
                return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("The former account's refresh must be discarded")
        } catch is CancellationError {
            XCTAssertEqual(tokens.accessToken, "second-owner")
            XCTAssertEqual(tokens.refreshToken, "second-refresh")
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
        }
    }

    func testConditionalInvalidationPreservesNewSession() throws {
        let formerRevision = client.sessionRevision
        let authorization = try JSONDecoder().decode(OAuthTokenResponse.self, from:
            Data(#"{"access_token":"second-owner","token_type":"Bearer"}"#.utf8))
        try client.acceptAuthorization(authorization, expectedRevision: formerRevision)
        let currentRevision = client.sessionRevision

        XCTAssertFalse(client.clearTokens(expectedRevision: formerRevision))
        XCTAssertEqual(tokens.accessToken, "second-owner")
        XCTAssertEqual(client.sessionRevision, currentRevision)
        XCTAssertTrue(client.clearTokens(expectedRevision: currentRevision))
        XCTAssertTrue(tokens.accessToken.isEmpty)
    }

    func testNonterminalRefreshResponsesPreserveSession() async throws {
        tokens.refreshToken = "valid-refresh"
        let revision = client.sessionRevision
        let responses = [
            (400, ""),
            (400, #"{"error":"invalid_request"}"#),
            (401, #"{"error":"invalid_client"}"#),
            (429, #"{"error":"temporarily_unavailable"}"#),
            (500, #"{"error":"server_error"}"#),
            (503, #"{"error":"invalid_grant"}"#),
        ]
        for (status, body) in responses {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                let isRefresh = request.url?.path.hasSuffix("/token") == true
                return (HTTPURLResponse(url: request.url!, statusCode: isRefresh ? status : 401,
                                        httpVersion: nil, headerFields: nil)!,
                        isRefresh ? Data(body.utf8) : Data())
            }
            do {
                let _: ServerUser = try await client.request(.me)
                XCTFail("Refresh failure must be reported for status \(status)")
            } catch let error as ServerError {
                guard case .serverError = error else {
                    XCTFail("A nonterminal refresh must remain retryable, got \(error)")
                    continue
                }
            }
            XCTAssertEqual(tokens.accessToken, "first-owner", "Status \(status)")
            XCTAssertEqual(tokens.refreshToken, "valid-refresh", "Status \(status)")
            XCTAssertEqual(client.sessionRevision, revision, "Status \(status)")
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2, "Status \(status)")
        }
    }

    func testRefreshTransportFailurePreservesSession() async throws {
        tokens.refreshToken = "valid-refresh"
        let revision = client.sessionRevision
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.hasSuffix("/token") == true { throw URLError(.timedOut) }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            let _: ServerUser = try await client.request(.me)
            XCTFail("The timed-out refresh must be reported")
        } catch {
            XCTAssertEqual((error as NSError).domain, NSURLErrorDomain)
            XCTAssertEqual((error as NSError).code, URLError.timedOut.rawValue)
        }
        XCTAssertEqual(tokens.accessToken, "first-owner")
        XCTAssertEqual(tokens.refreshToken, "valid-refresh")
        XCTAssertEqual(client.sessionRevision, revision)
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }
}
