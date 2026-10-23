import XCTest
@testable import Life_USTC

final class ServerPublicUserProfileTests: XCTestCase {
    private var client: ServerClient!

    override func setUp() {
        MockURLProtocol.reset()
        client = ServerClient(configuration: .init(baseURL: URL(string: "https://profiles.example")!,
                                                  session: MockURLProtocol.mockSession(), tokenStore: MockTokenStore()))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    @MainActor
    func testPublicProfileUsesActualServerCountsAndContributionDaysWithoutAuthentication() async {
        MockURLProtocol.stubJSON(profile())
        let model = ServerPublicUserProfileModel(client: client)
        await model.load(identifier: "student")
        XCTAssertEqual(model.profile?.user.id, "server-user")
        XCTAssertEqual(model.profile?.user.counts.comments, 4)
        XCTAssertEqual(model.profile?.user.counts.uploads, 2)
        XCTAssertEqual(model.profile?.totalContributions, 91)
        XCTAssertEqual(model.profile?.weeks.map { $0.map(\.date) }, [["2026-10-22", "2026-10-23"]])
        XCTAssertEqual(model.profile?.weeks.first?.map(\.count), [0, 3])
        XCTAssertNil(MockURLProtocol.capturedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    @MainActor
    func testFailedRefreshPreservesSameProfileButFailedDifferentUserNeverShowsPreviousProfile() async {
        let model = ServerPublicUserProfileModel(client: client)
        MockURLProtocol.stubJSON(profile())
        await model.load(identifier: "student")
        MockURLProtocol.stubJSON(["error": "Offline"], statusCode: 503)
        await model.load(identifier: "student")
        XCTAssertEqual(model.profile?.user.id, "server-user")
        XCTAssertNotNil(model.error)
        await model.load(identifier: "missing-user")
        XCTAssertNil(model.profile)
        XCTAssertNotNil(model.error)
        MockURLProtocol.stubJSON(profile(id: "retried-user"))
        await model.load(identifier: "missing-user")
        XCTAssertEqual(model.profile?.user.id, "retried-user")
        XCTAssertNil(model.error)
    }

    @MainActor
    func testResponseFromChangedSessionDoesNotReplaceProfile() async throws {
        let client = self.client!
        let responseData = try JSONSerialization.data(withJSONObject: profile())
        MockURLProtocol.requestHandler = { request in
            client.clearTokens()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseData)
        }
        let model = ServerPublicUserProfileModel(client: client)
        await model.load(identifier: "student")
        XCTAssertNil(model.profile)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
    }

    private func profile(id: String = "server-user") -> [String: Any] {
        ["user": ["id": id, "username": "student", "name": "Student", "image": NSNull(),
                  "createdAt": "2025-09-01T08:00:00+08:00", "_count": ["comments": 4, "uploads": 2, "homeworksCreated": 1]],
         "weeks": [[ ["date": "2026-10-22", "count": 0], ["date": "2026-10-23", "count": 3] ]],
         "totalContributions": 91]
    }
}
