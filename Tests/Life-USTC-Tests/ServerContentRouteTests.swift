import XCTest
@testable import Life_USTC

final class ServerContentRouteTests: XCTestCase {
    private let base = URL(string: "https://life.example")!

    func testSupportedPublicAndWorkspaceDestinationsRoundTrip() {
        let routes: [ServerContentRoute] = [
            .course(1001), .section(42), .teacher(3), .youngEvent("event-1"),
            .organizer("organizer-1"), .comment("comment-1"), .publicProfile("student"),
            .publication("publication-1"), .publicationSources, .todos, .homeworks, .exams, .calendar,
        ]
        for route in routes {
            XCTAssertEqual(ServerContentRoute(url: route.url(baseURL: base), baseURL: base), route)
        }
        XCTAssertEqual(Set(routes).count, routes.count)
        XCTAssertNotEqual(ServerContentRoute.course(42), .section(42))
    }

    func testCustomSchemeUsesTheSameNativeSectionIdentity() {
        let url = URL(string: "dev.tiankaima.life-ustc://catalog/sections/42")!
        XCTAssertEqual(ServerContentRoute(url: url, baseURL: base), .section(42))
    }

    func testOAuthCallbackAndWebsiteOnlyPagesStayOutsideContentRouting() {
        for raw in [
            "dev.tiankaima.life-ustc://auth/callback?code=test-code&state=test-state",
            "https://life.example/account/settings/security",
            "https://life.example/admin", "https://life.example/search?q=course",
            "https://life.example/community/comments/guide",
            "https://life.example/catalog/young-events/calendar",
            "https://life.example/catalog/sections/42/comments",
            "https://life.example/api/catalog/links/resolve?slug=academic",
        ] {
            XCTAssertNil(ServerContentRoute(url: URL(string: raw)!, baseURL: base), raw)
        }
    }

    func testOtherBackendAndInvalidCatalogIdentifiersDoNotOpenCurrentBackendObjects() {
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://another.example/catalog/sections/42")!, baseURL: base))
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://life.example/catalog/sections/0")!, baseURL: base))
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://life.example/catalog/courses/missing")!, baseURL: base))
    }

    func testWebHandoffsPreserveSearchTextAndCanonicalLinkSlug() {
        let search = ServerWebLinks.workspaceSearch("作业 & calendar", baseURL: base)
        XCTAssertEqual(search.path, "/search")
        XCTAssertEqual(URLComponents(url: search, resolvingAgainstBaseURL: false)?.queryItems,
                       [.init(name: "q", value: "作业 & calendar")])
        let link = ServerWebLinks.campusLink("academic", baseURL: base)
        XCTAssertEqual(link.path, "/api/catalog/links/resolve")
        XCTAssertEqual(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems,
                       [.init(name: "slug", value: "academic")])
    }
}
