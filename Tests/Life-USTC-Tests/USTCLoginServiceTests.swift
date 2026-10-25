import Foundation
import XCTest
@testable import Life_USTC

final class USTCLoginServiceTests: XCTestCase {
    private static let aasURLs = [
        "https://jw.ustc.edu.cn/ucas-sso/login",
        "https://passport.ustc.edu.cn/login?service=https%3A%2F%2Fjw.ustc.edu.cn%2Fucas-sso%2Flogin",
        "https://jw.ustc.edu.cn/",
    ]
    private static let blackboardCASURL = "https://passport.ustc.edu.cn/login?service=https%3a%2f%2fwww.bb.ustc.edu.cn%2fwebapps%2fbb-SSOIntegrationDemo-BBLEARN%2fexecute%2fauthValidate%2fcustomLogin%3freturnUrl%3dhttp%3a%2f%2fwww.bb.ustc.edu.cn%2fwebapps%2fportal%2fframeset.jsp%26authProviderId%3d_103_1"
    private static let blackboardHomeURL = "https://www.bb.ustc.edu.cn/webapps/portal/execute/tabs/tabAction?tab_tab_group_id=_1_1"
    private static let blackboardLinkURL = "https://www.bb.ustc.edu.cn/nginx_auth/login.php?next=abc&mode=1"
    private static let blackboardFinalURL = "https://www.bb.ustc.edu.cn/complete?ticket=synthetic"
    private static let graduateURLs = [
        "https://app.ustc.edu.cn/a_ustc/api/cas/index?redirect=https://app.ustc.edu.cn/site/examManage/index&from=wap",
        "https://id.ustc.edu.cn/cas/login?service=https://app.ustc.edu.cn/a_ustc/api/cas/index?redirect=https%3A%2F%2Fapp.ustc.edu.cn%2Fsite%2FtimeTableQuery%2Findex&from=wap",
    ]

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testAASSessionUsesOriginalRequestOrderAndExactHomeURL() async throws {
        for (finalURL, expected) in [
            ("https://jw.ustc.edu.cn/home", true),
            ("https://jw.ustc.edu.cn/home?next=1", false),
            ("https://jw.ustc.edu.cn/home/", false),
        ] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                Self.response(request.url?.absoluteString == Self.aasURLs.last ? finalURL : request.url!.absoluteString)
            }

            let result = try await USTCAASService(session: MockURLProtocol.mockSession()).establishSession()

            XCTAssertEqual(result, expected, finalURL)
            XCTAssertEqual(requestURLs, Self.aasURLs)
            XCTAssertTrue(MockURLProtocol.capturedRequests.allSatisfy { $0.httpMethod == "GET" && $0.httpBody == nil })
        }
    }

    func testAASSessionStopsAtTransportFailure() async {
        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString == Self.aasURLs[1] { throw URLError(.timedOut) }
            return Self.response(request.url!.absoluteString)
        }

        do {
            _ = try await USTCAASService(session: MockURLProtocol.mockSession()).establishSession()
            XCTFail("AAS setup must propagate transport errors")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }

        XCTAssertEqual(requestURLs, Array(Self.aasURLs.prefix(2)))
    }

    func testBlackboardSessionKeepsInitialResponseSuccessAfterBothLinks() async throws {
        for initiallySuccessful in [true, false] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                switch request.url!.absoluteString {
                case Self.blackboardCASURL:
                    return Self.response(
                        initiallySuccessful ? Self.blackboardHomeURL : Self.blackboardCASURL,
                        body: #"<a href="login.php?next=abc&amp;mode=1">Continue</a>"#
                    )
                case Self.blackboardLinkURL:
                    return Self.response(Self.blackboardLinkURL, body: "<a href=\"\(Self.blackboardFinalURL)\">Final</a>")
                case Self.blackboardFinalURL:
                    return Self.response(initiallySuccessful ? Self.blackboardCASURL : Self.blackboardHomeURL)
                default:
                    throw URLError(.badURL)
                }
            }

            let result = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).establishSession()

            XCTAssertEqual(result, initiallySuccessful)
            XCTAssertEqual(requestURLs, [Self.blackboardCASURL, Self.blackboardLinkURL, Self.blackboardFinalURL])
        }
    }

    func testBlackboardSessionDoesNotSkipAnUnmatchedFirstAnchor() async throws {
        MockURLProtocol.requestHandler = { _ in
            Self.response(Self.blackboardHomeURL, body: #"<a href="help">Help</a><a href="login.php">Login</a>"#)
        }

        let result = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).establishSession()

        XCTAssertTrue(result)
        XCTAssertEqual(requestURLs, [Self.blackboardCASURL])
    }

    func testBlackboardSessionStopsWhenFirstFinalAnchorCannotBecomeURL() async throws {
        for body in [
            #"<a>Missing href</a><a href="https://example.test/ignored">Later</a>"#,
            #"<a href="https://[broken">Invalid URL</a><a href="https://example.test/ignored">Later</a>"#,
            "<p>No links</p>",
        ] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                if request.url?.absoluteString == Self.blackboardCASURL {
                    return Self.response(Self.blackboardHomeURL, body: #"<a href="login.php?next=abc&amp;mode=1">Continue</a>"#)
                }
                return Self.response(Self.blackboardLinkURL, body: body)
            }

            let result = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).establishSession()

            XCTAssertTrue(result)
            XCTAssertEqual(requestURLs, [Self.blackboardCASURL, Self.blackboardLinkURL])
        }
    }

    func testBlackboardSessionPropagatesEitherHopFailure() async {
        for failedRequest in [2, 3] {
            MockURLProtocol.reset()
            MockURLProtocol.requestHandler = { request in
                if MockURLProtocol.capturedRequests.count == failedRequest { throw URLError(.timedOut) }
                if request.url?.absoluteString == Self.blackboardCASURL {
                    return Self.response(Self.blackboardHomeURL, body: #"<a href="login.php?next=abc&amp;mode=1">Continue</a>"#)
                }
                return Self.response(Self.blackboardLinkURL, body: "<a href=\"\(Self.blackboardFinalURL)\">Final</a>")
            }

            do {
                _ = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).establishSession()
                XCTFail("Blackboard hop errors must propagate even when the initial URL indicates success")
            } catch {
                XCTAssertEqual((error as? URLError)?.code, .timedOut)
            }

            XCTAssertEqual(requestURLs, Array([Self.blackboardCASURL, Self.blackboardLinkURL, Self.blackboardFinalURL].prefix(failedRequest)))
        }
    }

    func testBlackboardSessionTreatsInvalidUTF8AsAnEmptyDocument() async throws {
        MockURLProtocol.requestHandler = { _ in
            let (response, body) = Self.response(Self.blackboardHomeURL, body: #"<a href="login.php">Continue</a>"#)
            return (response, body + Data([0xff]))
        }

        let result = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).establishSession()

        XCTAssertTrue(result)
        XCTAssertEqual(requestURLs, [Self.blackboardCASURL])
    }

    func testGraduateSessionSetupPrecedesAppSelectionAndStaticMatching() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            if request.url?.path == "/xkjg/wap/default/get-index" {
                return Self.response(url, body: #"{"d":{"lists":[{"course_name":"Math(A)"}]}}"#)
            }
            if request.url?.path == "/curriculum/301/courses.json" {
                return Self.response(url, body: #"[{"id":7,"lessonCode":"A"}]"#)
            }
            return Self.response(url)
        }
        let service = USTCStaticService(session: MockURLProtocol.mockSession())

        try await service.establishGraduateAppSession()
        let ids = try await service.fetchGraduateCourseIDs(semesterId: "301")

        XCTAssertEqual(ids, [7])
        XCTAssertEqual(requestURLs, Self.graduateURLs + [
            "https://app.ustc.edu.cn/xkjg/wap/default/get-index",
            "https://static.life-ustc.tiankaima.dev/curriculum/301/courses.json",
        ])
    }

    func testGraduateSessionSetupStopsOnTheFirstFailure() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            try await USTCStaticService(session: MockURLProtocol.mockSession()).establishGraduateAppSession()
            XCTFail("The second app setup request must not follow a failed first request")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }

        XCTAssertEqual(requestURLs, Array(Self.graduateURLs.prefix(1)))
    }

    func testGraduateInvalidAppResponseAfterSetupStopsBeforeStaticRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            Self.response(request.url!.absoluteString, body: "{")
        }
        let service = USTCStaticService(session: MockURLProtocol.mockSession())
        try await service.establishGraduateAppSession()

        do {
            _ = try await service.fetchGraduateCourseIDs(semesterId: "301")
            XCTFail("Malformed app data must stop before fetching static courses")
        } catch {}

        XCTAssertEqual(requestURLs, Self.graduateURLs + ["https://app.ustc.edu.cn/xkjg/wap/default/get-index"])
    }

    func testLegacyServiceMarkupUsesOriginalFoundationEncoding() throws {
        let service = try XCTUnwrap(URL(string: "https://example.test/path?a=one+two&b=%2F#part"))

        let marked = service.ustcCASLoginMarkup()

        XCTAssertEqual(marked.absoluteString, "https://passport.ustc.edu.cn/login?service=https://example.test/path?a%3Done+two%26b%3D%252F%23part")
        let components = try XCTUnwrap(URLComponents(url: marked, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "service", value: service.absoluteString)])
    }

    private var requestURLs: [String] {
        MockURLProtocol.capturedRequests.compactMap { $0.url?.absoluteString }
    }

    private static func response(_ url: String, body: String = "") -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
    }
}
